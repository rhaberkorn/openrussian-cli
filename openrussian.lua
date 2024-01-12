#!/usr/bin/lua5.2

local driver = require "luasql.sqlite3"
local lutf8 = require "lua-utf8"

local ACCENT = lutf8.char(0x0301) -- Accent combining character

local langs = {}

local search_words = {}

local function usage(stream)
	stream:write("Usage: ", arg[0], " [-L<lang>] [-V] [-p] <pattern...>\n",
	             "\t-L<lang>    Overwrite translation language (currently en or de)\n",
	             "\t-V          Verbatim matching (no case folding and inflections)\n",
	             "\t-p          Print Troff code to stdout\n")
end

for i = 1, #arg do
	if arg[i]:sub(1, 1) == "-" then
		local opt = arg[i]:sub(2)

		if opt:sub(1, 1) == "L" then
			if #opt > 1 then
				table.insert(langs, opt:sub(2))
			elseif i == #arg then
				usage(io.stderr)
				os.exit(false)
			else
				table.insert(langs, arg[i+1])
				i = i + 1
			end
		elseif opt == "V" then
			verbatim = true
		elseif opt == "p" then
			use_stdout = true
		elseif opt == "C" then
			-- This is a "secret" command used for implementing
			-- auto-completions.
			-- It will usually be the first argument.
			auto_complete = true
		else
			usage(io.stderr)
			os.exit(false)
		end
	else
		table.insert(search_words, arg[i])
	end
end

if #search_words == 0 then
	usage(io.stderr);
	os.exit(false)
end

-- Allowing multiple arguments to be concat into the search words
-- is useful when searching for a translation which may contain
-- spaces without quoting the entire search term.
local search_word = table.concat(search_words, " ")..
                    (auto_complete and "*" or "")

if #langs == 0 then langs = {os.setlocale(nil, "ctype"):match("^([^_]+)")} end

-- FIXME: Currently only English and German are actually
-- contained in the database, but this might change.
-- Perhaps query the availability dynamically.
if langs[1] ~= "en" and langs[1] ~= "de" then langs = {"en"} end

local function dirname(path)
	return path:match("^(.*)/.+$") or "."
end

-- Calculate the installation prefix at runtime, in order to locate
-- the installed data base.
-- This way, we don't have to preprocess the script during installation
local PREFIX = dirname(arg[0]).."/.."

local database = PREFIX.."/share/openrussian/openrussian-sqlite3.db"
if not io.open(database) then database = "openrussian-sqlite3.db" end

local out_stream

local env = assert(driver.sqlite3())
local con = assert(env:connect(database))

-- A SQL-compatible globber.
-- Necessary since globbing is usually done as part of the
-- SQL query.
--
-- NOTE: This may be reimplemented more efficiently by translating
-- the glob pattern to a Lua pattern.
-- Unfortunately, the Glob pattern syntax appears to be undefined,
-- probably because it defaults to the system glob.
--
-- Alternatively, we might override the MATCH function with Lua patterns
-- and use MATCH instead of GLOB, but this might be inefficient.
-- In order to make use of the query optimizer, we must either use
-- LIKE or GLOB.
--
-- Yet another alternative might be to parse all translations into
-- a separate index, speeding up translation lookups and avoiding
-- the need for globbing in Lua here.
function glob(pattern, str)
	local cur = assert(con:execute(string.format([[
		SELECT '%s' GLOB '%s'
	]], con:escape(str), con:escape(pattern))))
	local row = assert(cur:fetch())
	cur:close()

	return row ~= 0
end

-- Turns a character followed by apostroph into a combined
-- accented character.
-- NOTE: This encodes the accent (u0301) in bytes, so it can be
-- used for printing to stdout or into Troff code.
local function map_accented(str)
	return (lutf8.gsub(str, "'", ACCENT))
end
-- FIXME: map_accented() does not work for tables since tbl will count the
-- combined character as two. Theoretically, Groff has composite characters
-- like \u[u043E_0301] but they don't work for all the cyrillic
-- vowels.
-- If we really wanted to, we could replace every accented character
-- with an inline macro that is defined at Troff runtime depending on the
-- output device, so we could get accented characters in PDF tables at least.
local function map_tbl(str)
	return (lutf8.gsub(str, "(.)'", "\\fI%1\\fP"))
end

local function format_declensions(...)
	local decl = {}

	for i, decl_id in ipairs{...} do
		if type(decl_id) == "number" then
			local cur = assert(con:execute(string.format([[
				SELECT * FROM declensions WHERE id = %d
			]], decl_id)))
			local row = cur:fetch({}, "a")
			cur:close()

			for _, case in ipairs{"nom", "gen", "dat", "acc", "inst", "prep"} do
				decl[case] = decl[case] or {}
				local val = lutf8.gsub(row and row[case] or '-', "[;,] *%(", " (")
				val = lutf8.gsub(val, "[;,] *", ", ")
				decl[case][i] = map_tbl(val)
			end
		else
			for _, case in ipairs{"nom", "gen", "dat", "acc", "inst", "prep"} do
				decl[case] = decl[case] or {}
				decl[case][i] = map_tbl(decl_id or '-')
			end
		end
	end

	out_stream:write('Nominative;',   table.concat(decl.nom, ';'), '\n')
	out_stream:write('Genitive;',     table.concat(decl.gen, ';'), '\n')
	out_stream:write('Dative;',       table.concat(decl.dat, ';'), '\n')
	out_stream:write('Accusative;',   table.concat(decl.acc, ';'), '\n')
	out_stream:write('Instrumental;', table.concat(decl.inst, ';'), '\n')
	out_stream:write('Prepositive;',  table.concat(decl.prep, ';'), '\n')
end

local format = {} -- formatter functions by word category

function format.noun(word_id, accented)
	local cur = assert(con:execute(string.format([[
		SELECT * FROM nouns WHERE word_id = %d
	]], word_id)))
	local row = cur:fetch({}, "a")
	cur:close()

	-- NOTE: This can probably happen as with any other word category
	-- (example?)
	if not row then return end

	out_stream:write('.SH GENDER\n')
	if row.gender and row.gender ~= "" then
		local genders = {m = "male", f = "female", n = "neuter"}
		out_stream:write(genders[row.gender] or row.gender, ', ')
	end
	out_stream:write(row.animate == 1 and 'animate' or 'inanimate', '\n')

	if row.partner and row.partner ~= "" then
		-- NOTE: Noun "partners" seem to be male/female counterparts.
		-- FIXME: It would also be nice to include an accented version,
		-- but since the DB lists the partner as a string instead of
		-- word_id, finding the right entry could be unreliable.
		out_stream:write('.SH PARTNER\n',
		                 map_accented(row.partner), '\n')
	end

	out_stream:write('.SH DECLENSION\n',
	                 '.TS\n',
	                 'allbox,tab(;);\n',
	                 'L  LB LB\n',
	                 'LB L  L.\n',
	                 ';Singular;Plural\n')
	if row.indeclinable == 1 then
		format_declensions(accented, accented)
	else
		-- FIXME: The ids turn out to be sometimes invalid and it would
		-- be better to omit the entire DECLENSION section.
		format_declensions(row.pl_only == 0 and row.decl_sg_id or '-',
		                   row.sg_only == 0 and row.decl_pl_id or '-')
	end
	-- NOTE: It is unclear why the trailing .sp is necessary
	out_stream:write('.TE\n',
	                 '.sp\n')
end

function format.adjective(word_id, accented)
	local cur = assert(con:execute(string.format([[
		SELECT * FROM adjectives WHERE word_id = %d
	]], word_id)))
	local row = cur:fetch({}, "a")
	cur:close()

	-- NOTE: Seldomly (e.g. nesomnenno), there is no entry in adjectives
	if not row then return end

	if row.decl_m_id and row.decl_n_id and row.decl_f_id and row.decl_pl_id then
		out_stream:write('.SH DECLENSION\n',
		                 '.TS\n',
		                 'allbox,tab(;);\n',
		                 'L  LB LB LB LB\n',
		                 'LB L  L  L  L.\n',
		                 ';Male;Neutral;Female;Plural\n')
		format_declensions(row.decl_m_id, row.decl_n_id, row.decl_f_id, row.decl_pl_id)
		if row.short_m or row.short_n or row.short_f or row.short_pl then
			out_stream:write('Short;',
			                 map_tbl(row.short_m or '-'), ';',
			                 map_tbl(row.short_n or '-'), ';',
			                 map_tbl(row.short_f or '-'), ';',
			                 map_tbl(row.short_pl or '-'), '\n')
		end
		-- NOTE: It is unclear why the trailing .sp is necessary
		out_stream:write('.TE\n',
		                 '.sp\n')
	end

	if row.comparative and row.comparative ~= "" then
		out_stream:write('.SH COMPARATIVE\n',
		                 map_accented(lutf8.gsub(row.comparative, "[;,] *", ", ")), '\n')
	end

	if row.superlative and row.superlative ~= "" then
		out_stream:write('.SH SUPERLATIVE\n',
		                 map_accented(lutf8.gsub(row.superlative, "[;,] *", ", ")), '\n')
	end
end

-- NOTE: There is no separate table for adverbs
-- Currently, we wouldn't print more than the category, which is also in the
-- header, so it is omitted.
function format.adverb(word_id, accented) end

function format.verb(word_id, accented)
	local cur = assert(con:execute(string.format([[
		SELECT * FROM verbs JOIN conjugations ON verbs.presfut_conj_id = conjugations.id
		WHERE verbs.word_id = %d
	]], word_id)))
	local row = cur:fetch({}, "a")
	cur:close()

	-- NOTE: Seldomly (e.g. est' -- to be), there is no entry in verbs
	if not row then return end

	if row.aspect then
		out_stream:write('.SH ASPECT\n',
		                 row.aspect, '\n')
	end

	if row.partner and row.partner ~= "" then
		-- NOTE: Verb partners seem to be the aspect partners.
		-- They are either comma or semicolon separated.
		-- FIXME: It would also be nice to include an accented version,
		-- but since the DB lists the partner as a string instead of
		-- word_id, finding the right entry could be unreliable 
		out_stream:write('.SH PARTNER\n',
		                 lutf8.gsub(map_accented(row.partner), "[;,] *", ", "), '\n')
	end

	-- FIXME: Can we assume that verbs without specified aspect are always
	-- perfective?
	-- NOTE: Very seldomly (eg. widat'), all conjugations are missing.
	-- Sometimes only the first person singular is missing.
	if row.sg1 or row.sg2 or row.sg3 or row.pl1 or row.pl2 or row.pl3 then
		out_stream:write('.SH ', row.aspect == "imperfective" and 'PRESENT\n' or 'FUTURE\n')
		if row.sg1 then out_stream:write(map_accented("\\[u042F] "), map_accented(row.sg1), '.\n', '.br\n') end
		out_stream:write(map_accented("\\[u0422]\\[u044B] "), map_accented(row.sg2), '.\n', '.br\n',
		                 map_accented("\\[u041E]\\[u043D]/\\[u041E]\\[u043D]\\[u0430]'/\\[u041E]\\[u043D]\\[u043E]' "),
		                         map_accented(row.sg3), '.\n', '.br\n',
		                 map_accented("\\[u041C]\\[u044B] "), map_accented(row.pl1), '.\n', '.br\n',
		                 map_accented("\\[u0412]\\[u044B] "), map_accented(row.pl2), '.\n', '.br\n',
		                 map_accented("\\[u041E]\\[u043D]\\[u0438]' "), map_accented(row.pl3), '.\n', '.br\n')
	end

	if row.past_m or row.past_f or row.past_n or row.past_pl then
		out_stream:write('.SH PAST\n',
		                 map_accented("\\[u041E]\\[u043D] "),
		                         map_accented(lutf8.gsub(row.past_m, "[,/]+", "/")), '.\n', '.br\n',
		                 map_accented("\\[u041E]\\[u043D]\\[u0430]' "),
		                         map_accented(lutf8.gsub(row.past_f, "[,/]+", "/")), '.\n', '.br\n',
		                 map_accented("\\[u041E]\\[u043D]\\[u043E]' "),
		                         map_accented(lutf8.gsub(row.past_n, "[,/]+", "/")), '.\n', '.br\n',
		                 map_accented("\\[u041E]\\[u043D]\\[u0438]' "),
		                         map_accented(lutf8.gsub(row.past_pl, "[,/]+", "/")), '.\n')
	end

	-- FIXME: Is the singular/plural distinction always obvious?
	-- FIXME: Seldom (eg. sxodit'), the plural is missing, but this may be a general
	-- bug of the entry.
	if row.imperative_sg or row.imperative_pl then
		out_stream:write('.SH IMPERATIVE\n',
		                 map_accented(row.imperative_sg), '! / ',
		                 map_accented(row.imperative_pl), '!\n')
	end
end

-- NOTE: There is no separate table for expressions
-- Currently, we wouldn't print more than the category, which is also in the
-- header, so it is omitted.
function format.expression(word_id, accented) end

function format.other(word_id, accented) end

local function get_translations(word_id)
	local ret = {}

	for _, lang in ipairs(langs) do
		local cur = assert(con:execute(string.format([[
			SELECT tl FROM translations
			WHERE word_id = %d AND lang = '%s'
		]], word_id, con:escape(lang))))
		local row = cur:fetch({}, "a")
		while row do
			-- NOTE: One entry might contain many comma-separated
			-- translations
			for word in lutf8.gmatch(row.tl..", ", "(.-), ") do
				table.insert(ret, word)
			end
			row = cur:fetch({}, "a")
		end
		cur:close()
	end

	return ret
end

-- Format reference to row from the words-table.
-- FIXME: Not printed bold since bold text and accents
-- don't work together (URxvt).
local function get_reference(word_row)
	return map_accented(word_row.accented or word_row.bare)..
	       '('..(word_row.type or "other")..')'
end

-- NOTE: This strips the accent char, so users can cut and paste from
-- generated output.
-- This is done from Lua, since the right-hand side of GLOB should be a constant
-- to allow optimizations:
-- https://www.sqlite.org/optoverview.html#the_like_optimization
--
-- TODO: Double-check whether the GLOB is actually optimized.
-- Theoretically, we need COLLATE BINARY for that.
--
-- FIXME: Case-folding UTF8 / Collating is not supported by SQLite3.
-- If we want to support case-insensitive matching, it is mandatory, though.
-- Could be done using the ICU extension:
-- https://www.sqlite.org/src/artifact?ci=trunk&filename=ext/icu/README.txt
local cur = assert(con:execute(string.format([[
	SELECT bare AS completions, * FROM words
	WHERE LIKELY(disabled = 0) AND bare GLOB '%s'
	ORDER BY rank
]], con:escape(lutf8.gsub(search_word, ACCENT, "")))))

local rows = {}
local row
repeat
	row = cur:fetch({}, "a")
	table.insert(rows, row)
until not row

cur:close()

if not verbatim then
	--[==[
	-- FIXME: These queries are tooo sloooow! Perhaps that's why the openrussion.org
	-- website does not allow searching by declension prefixes.
	-- This is because of the need for string-concatenations for every possible word
	-- and because the GLOBbing cannot be optimized, even in the most common cases.
	-- FIXME: This does not find braced-terms. Glob patterns are simply not powerful
	-- enough to express "optional brace".
	-- We'd probably need regexp for that.
	cur = assert(con:execute(string.format([[
		SELECT REPLACE(temp, "'", "") AS completions, words.* FROM words JOIN (
			-- Search word might be a noun or adjective declension
			SELECT nom||","||gen||","||dat||","||acc||","||inst||","||prep AS temp, word_id
			FROM declensions
			UNION
			-- Search word might be a special adjective inflection
			SELECT comparative||","||superlative||","||
			       short_m||","||short_f||","||short_n||","||short_pl AS temp, word_id
			FROM adjectives
			UNION
			-- Search word might be a verb imperative, past form or conjugation
			SELECT imperative_sg||","||imperative_pl||","||past_m||","||past_f||","||past_n||","||past_pl||
			       sg1||","||sg2||","||sg3||","||pl1||","||pl2||","||pl3 AS temp, verbs.word_id
			FROM verbs LEFT JOIN conjugations ON presfut_conj_id = conjugations.id
		) ON words.id = word_id
		WHERE LIKELY(disabled = 0) AND ","||completions||"," GLOB '*,%s,*'
		ORDER BY rank
	]], con:escape(lutf8.gsub(search_word, ACCENT, "")))))

	-- This is an alternative to the above query.
	-- It eliminates the concatenations, but has to iterate many tables redundantly.
	-- Effectively it is twice as slow as the above query...
	cur = assert(con:execute(string.format([[
		SELECT REPLACE(temp, "'", "") AS completions, words.* FROM words JOIN (
			-- Search word might be a noun or adjective declension
			SELECT nom AS temp, word_id FROM declensions
			UNION ALL
			SELECT gen AS temp, word_id FROM declensions
			UNION ALL
			SELECT dat AS temp, word_id FROM declensions
			UNION ALL
			SELECT acc AS temp, word_id FROM declensions
			UNION ALL
			SELECT inst AS temp, word_id FROM declensions
			UNION ALL
			SELECT prep AS temp, word_id FROM declensions
			UNION ALL
			-- Search word might be a special adjective inflection
			SELECT comparative AS temp, word_id FROM adjectives
			UNION ALL
			SELECT superlative AS temp, word_id FROM adjectives
			UNION ALL
			SELECT short_m AS temp, word_id FROM adjectives
			UNION ALL
			SELECT short_f AS temp, word_id FROM adjectives
			UNION ALL
			SELECT short_n AS temp, word_id FROM adjectives
			UNION ALL
			SELECT short_pl AS temp, word_id FROM adjectives
			UNION ALL
			-- Search word might be a verb imperative or past form
			SELECT imperative_sg AS temp, word_id FROM verbs
			UNION ALL
			SELECT imperative_pl AS temp, word_id FROM verbs
			UNION ALL
			SELECT past_m AS temp, word_id FROM verbs
			UNION ALL
			SELECT past_f AS temp, word_id FROM verbs
			UNION ALL
			SELECT past_n AS temp, word_id FROM verbs
			UNION ALL
			SELECT past_pl AS temp, word_id FROM verbs
			UNION ALL
			-- Search word might be a verb conjugation
			SELECT sg1 AS temp, word_id FROM conjugations
			UNION ALL
			SELECT sg2 AS temp, word_id FROM conjugations
			UNION ALL
			SELECT sg3 AS temp, word_id FROM conjugations
			UNION ALL
			SELECT pl1 AS temp, word_id FROM conjugations
			UNION ALL
			SELECT pl2 AS temp, word_id FROM conjugations
			UNION ALL
			SELECT pl3 AS temp, word_id FROM conjugations
		) ON words.id = word_id
		WHERE LIKELY(disabled = 0) AND completions GLOB '%s'
		ORDER BY rank
	]], con:escape(lutf8.gsub(search_word, ACCENT, "")))))
	]==]

	-- This query uses a new `bare_inflections` table, since all queries
	-- using existing tables (see above) are way too slow, especially for
	-- autocompletions.
	-- NOTE: The right-hand side of GLOB must be a constant, so that it can be
	-- optimized using the index.
	cur = assert(con:execute(string.format([[
		SELECT bare_inflections.bare AS completions, words.*
		FROM words JOIN bare_inflections ON words.id = word_id
		WHERE LIKELY(disabled = 0) AND completions GLOB '%s'
		ORDER BY rank
	]], con:escape(lutf8.gsub(search_word, ACCENT, "")))))

	repeat
		row = cur:fetch({}, "a")
		table.insert(rows, row)
	until not row

	cur:close()
end

-- Only if we do not find a Russian word, we try to find a translation.
-- This is not wrapped with the above query into one using a LEFT JOIN since
-- two queries are significantly faster - probably because of having to perform less
-- string concatenations.
if #rows == 0 then
	for _, lang in ipairs(langs) do
		-- NOTE: The translation entry frequently contains a comma-separated
		-- list of translations
		--
		-- FIXME: Case folding only works for ASCII, which should be sufficient for
		-- German/English text (almost)...
		-- FIXME: The string concatenation is a real slow-down and the GLOB cannot
		-- be optimized.
		-- Perhaps the translations should be in their own (new) indexed table.
		cur = assert(con:execute(string.format([[
			SELECT %s(", "||tl||", ") AS completions, words.*
			FROM words JOIN translations ON words.id = word_id
			WHERE LIKELY(disabled = 0) AND lang = '%s' AND completions GLOB %s('*, %s, *')
			ORDER BY rank
		]], verbatim and "" or "LOWER", con:escape(lang), verbatim and "" or "LOWER", con:escape(search_word))))

		repeat
			row = cur:fetch({}, "a")
			table.insert(rows, row)
		until not row

		cur:close()
	end
end

if auto_complete then
	-- FIXME: See above for notes on case-folding
	local search_word_bare = lutf8.gsub(search_word, ACCENT, "")
	search_word_bare = verbatim and search_word_bare or search_word_bare:lower()

	for _, row in ipairs(rows) do
		-- NOTE: This code is reused for Russian base words, inflections and translated lookups,
		-- so there is a common `completions` column.
		-- Russian words can be treated like single-word translations.
		-- Terms in this column can be comma-separated with and without spaces and
		-- there may be braces.
		for word in lutf8.gmatch(row.completions..",", " *%(?(.-)%)?,") do
			if glob(search_word, word) then
				io.stdout:write(search_words[#search_words],
				                lutf8.sub(word, lutf8.len(search_word_bare)), "\n")
			end
		end
	end

	os.exit(true)
end

if #rows == 0 then
	io.stderr:write('Word "', search_word, '" not found!\n')
	os.exit(false)
end

-- Filter out duplicates
local word_ids = {}
local unique_rows = {}

for _, row in ipairs(rows) do
	if not word_ids[row.id] then
		table.insert(unique_rows, row)
		word_ids[row.id] = true
	end
end

if #unique_rows == 1 then
	row = unique_rows[1]
else
	for i, row in ipairs(unique_rows) do
		local word_accented = row.accented or row.bare
		local tl = get_translations(row.id)

		io.stdout:write(i, ") ", map_accented(word_accented))
		if #tl > 0 then io.stdout:write(" (", table.concat(tl, ", "), ")") end
		io.stdout:write("\n")
	end

	repeat
		io.stdout:write("Show [1..", #unique_rows, ", press enter to cancel]? "):flush()
		-- If stdin is not available we always assume 1.
		-- This can especially happen when using `make check`.
		local choice = io.stdin:read() or "1"
		if choice == "" or choice:lower() == "q" then os.exit() end
		row = unique_rows[tonumber(choice)]
	until row
end

local word_id = row.id
-- NOTE: Some words (e.g. personal pronouns) apparently do not
-- come with accents!?
local word_accented = row.accented or row.bare
local word_derived_from = row.derived_from_word_id
local word_audio = row.audio
local word_type = row.type or "other"
local word_usages = {}

for _, lang in ipairs(langs) do
	table.insert(word_usages, row["usage_"..lang])
end

-- Open stream only now, after no more messages have to be written to
-- stdout/stderr.
if use_stdout then
	out_stream = io.stdout
else
	local size_stream = io.popen("stty size")
	local columns = size_stream and size_stream:read("*a"):match("%d+ (%d+)") or 80
	out_stream = io.popen("groff -Kutf8 -Tutf8 -t -man -rLL="..columns.."n -rLT="..columns.."n | less -r", "w")
end
assert(out_stream)

-- NOTE: The headers and footers shouldn't contain critical information
-- since they might not be printed at all.
out_stream:write('.\\" t\n',
                 '.TH "', row.bare, '" "', word_type, '" "')
if row.rank then
	out_stream:write('#', row.rank, row.level and ' ('..row.level..')' or '')
elseif row.level then
	out_stream:write(row.level)
end
out_stream:write('" "openrussian.lua" "openrussian.org"\n')

--
-- Generic WORD section with translation.
--
out_stream:write('.SH WORD\n',
                 map_accented(word_accented))
local tl = get_translations(word_id)
if #tl > 0 then
	out_stream:write(' \\-\\- ', table.concat(tl, ', '))
end
out_stream:write('\n')

--
-- Word-specific sections
-- NOTE: word_accented is required only for format.noun() and could be
-- avoided altogether.
--
format[word_type](word_id, word_accented)

--
-- Generic sections
--
if #word_usages > 0 then
	out_stream:write('.SH USAGE\n',
	                 table.concat(word_usages, ', '), '\n')
end

-- FIXME: Perhaps this should rather be part of the SEE ALSO section
if word_derived_from then
	cur = assert(con:execute(string.format([[
		SELECT bare, accented, type FROM words
		WHERE LIKELY(disabled = 0) AND id = %d
	]], word_derived_from)))
	row = assert(cur:fetch({}, "a"))
	cur:close()

	out_stream:write('.SH DERIVED FROM\n',
	                 get_reference(row), '\n')
end

--
-- NOTE: There can be many examples, so print them late.
--
rows = {}
for _, lang in ipairs(langs) do
	cur = assert(con:execute(string.format([[
		SELECT ru, start, length, tl
		FROM sentences_words JOIN sentences ON sentence_id = sentences.id
		WHERE word_id = %d AND lang = '%s'
	]], word_id, con:escape(lang))))

	repeat
		row = cur:fetch({}, "a")
		table.insert(rows, row)
	until not row

	cur:close()
end
if #rows > 0 then
	out_stream:write('.SH EXAMPLES\n')

	for _, row in ipairs(rows) do
		-- FIXME: The accent is not always available in the default
		-- italic font when formatting for PDF.
		local ru_hl = lutf8.sub(row.ru, 1, row.start)..'\\fI'..
		              lutf8.sub(row.ru, row.start+1, row.start+1+row.length-1)..'\\fP'..
		              lutf8.sub(row.ru, row.start+1+row.length)

		out_stream:write('.TP\n',
		                 map_accented(ru_hl), '\n',
		                 row.tl, '\n')
	end
end

-- Audio recordings might be useful occasionally, but this is an offline/terminal
-- application, so it makes sense to print them last (like URLs in manpages).
--
-- NOTE: There is an UE man-macro, but it doesn't seem to be very helpful here and
-- seems to bring no advantages when formatting as a PDF.
-- It could be typset in the default fixed-width font (\fC), but it does not contain
-- cyrillic characters, so we don't do that either.
if word_audio then
	out_stream:write('.SH AUDIO\n',
	                 word_audio, '\n')
end

-- Disable adjusting (space-stretching) for the related-word lists.
-- Don't forget to enable this again if something follows these sections.
out_stream:write('.na\n')

-- NOTE: The results are grouped by relation, so that they can be
-- easily printed in one section per relation.
-- Unfortunately, we cannot define custom collating sequences with LuaSQL.
-- FIXME: Print this under a single SEE ALSO master section?
-- FIXME: Results should perhaps be ordered by `type`?
cur = assert(con:execute(string.format([[
	SELECT bare, accented, type, relation
	FROM words_rels JOIN words ON rel_word_id = words.id
	WHERE LIKELY(disabled = 0) AND words_rels.word_id = %d
	ORDER BY relation, rank
]], word_id)))

local cur_relation
row = cur:fetch({}, "a")
while row do
	if cur_relation ~= row.relation then
		cur_relation = row.relation
		out_stream:write('.SH ', cur_relation:upper(), '\n')
	end
	out_stream:write(get_reference(row))
	row = cur:fetch({}, "a")
	out_stream:write(row and row.relation == cur_relation and ', ' or '\n')
end

cur:close()

--
-- Cleanup
-- NOTE: Not strictly necessary, as everything is garbage-collected anyway
--
con:close()
env:close()

if out_stream then out_stream:close() end
