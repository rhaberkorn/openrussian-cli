#!/usr/bin/lua5.2

local driver = require "luasql.sqlite3"

local function usage(stream)
	stream:write("Usage: ", arg[0], " [-p] <word>\n")
end

for i = 1, #arg do
	if arg[i]:sub(1, 1) == "-" then
		if arg[i]:sub(2) == "p" then
			use_stdout = true
		else
			usage(io.stderr)
			os.exit(false)
		end
	else
		search_word = arg[i]
	end
end

if not search_word then
	usage(io.stderr);
	os.exit(false)
end

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
local lang = "en"

local env = assert(driver.sqlite3())
local con = assert(env:connect(database))

-- Turns a character followed by apostroph into a combined
-- accented character.
local function map_accented(str)
	return (str:gsub("'", "\\[u0301]"))
end
-- FIXME: This does not work for tables since tbl will count the
-- combined character as two. Theoretically, Groff has composite characters
-- like \u[u043E_0301] but they don't work for all the cyrillic
-- vocals.
local function map_tbl(str)
	return (str:gsub("(..)'", "\\fI%1\\fP"))
end

local function format_declension(tag, decl_id, short_form)
	local cur = assert(con:execute(string.format([[
		SELECT * FROM declensions WHERE id = %d
	]], decl_id)))
	local row = assert(cur:fetch({}, "a"))
	cur:close()
	out_stream:write(tag, ';', map_tbl(row.nom), ';', map_tbl(row.gen), ';',
	                 map_tbl(row.dat), ';', map_tbl(row.acc), ';',
	                 map_tbl(row.inst), ';', map_tbl(row.prep))
	if short_form then out_stream:write(';', map_tbl(short_form)) end
	out_stream:write('\n')
end

local function format_dummy_declension(tag, accented)
	accented = map_tbl(accented)
	out_stream:write(tag)
	for _ = 1, 6 do out_stream:write(';', accented) end
	out_stream:write('\n')
end

local format = {} -- formatter functions by word category

function format.noun(word_id, accented)
	local cur = assert(con:execute(string.format([[
		SELECT * FROM nouns WHERE word_id = %d
	]], word_id)))
	local row = assert(cur:fetch({}, "a"))
	cur:close()

	out_stream:write('.SH WORD\n',
	                 map_accented(accented), ' \\-\\- noun, ')
	if row.gender and row.gender ~= "" then
		local genders = {m = "male", f = "female", n = "neuter"}
		out_stream:write(genders[row.gender], ', ')
	end
	out_stream:write(row.animate == 1 and 'animate' or 'inanimate', '\n')

	if row.partner and row.partner ~= "" then
		-- FIXME: What exactly is a noun "partner"?
		-- Seems to be used mostly for male/female pairs etc.
		out_stream:write('.SH PARTNER\n',
		                 row.partner, '\n')
	end

	out_stream:write('.SH DECLENSION\n',
	                 '.TS\n',
	                 'allbox,tab(;);\n',
	                 'L  LB LB LB LB LB LB\n',
	                 'LB L  L  L  L  L  L.\n',
	                 ';Nominative;Genitive;Dative;Accusative;Instrumental;Prepositive\n')
	if row.pl_only == 0 then
		if row.indeclinable == 1 then
			format_dummy_declension('Singular', accented)
		else	                 
			format_declension('Singular', row.decl_sg_id)
		end
	end
	if row.sg_only == 0 then
		if row.indeclinable == 1 then
			format_dummy_declension('Plural', accented)
		else	                 
			format_declension('Plural', row.decl_pl_id)
		end
	end
	out_stream:write('.TE\n')
end

function format.adjective(word_id, accented)
	local cur = assert(con:execute(string.format([[
		SELECT * FROM adjectives WHERE word_id = %d
	]], word_id)))
	local row = assert(cur:fetch({}, "a"))
	cur:close()

	out_stream:write('.SH WORD\n',
	                 map_accented(accented), ' \\-\\- adjective\n')

	out_stream:write('.SH DECLENSION\n',
	                 '.TS\n',
	                 'allbox,tab(;);\n',
	                 'L  LB LB LB LB LB LB LB\n',
	                 'LB L  L  L  L  L  L  L.\n',
	                 ';Nominative;Genitive;Dative;Accusative;Instrumental;Prepositive;Short\n')
	format_declension('Male', row.decl_m_id, row.short_m)
	format_declension('Neutral', row.decl_n_id, row.short_n)
	format_declension('Female', row.decl_f_id, row.short_f)
	format_declension('Plural', row.decl_pl_id, row.short_pl)
	out_stream:write('.TE\n')

	if row.comparative then
		out_stream:write('.SH COMPARATIVE\n',
		                 map_accented(row.comparative), '\n')
	end

	if row.superlative then
		out_stream:write('.SH SUPERLATIVE\n',
		                 map_accented(row.superlative), '\n')
	end
end

function format.verb(word_id, accented)
	local cur = assert(con:execute(string.format([[
		SELECT * FROM verbs JOIN conjugations ON verbs.presfut_conj_id = conjugations.id
		WHERE verbs.word_id = %d
	]], word_id)))
	local row = assert(cur:fetch({}, "a"))
	cur:close()

	out_stream:write('.SH WORD\n',
	                 map_accented(accented), ' \\-\\- verb')
	if row.aspect then out_stream:write(', ', row.aspect) end
	out_stream:write('\n')

	if row.partner and row.partner ~= "" then
		-- NOTE: Verb partners seem to be the aspect partners
		out_stream:write('.SH PARTNER\n',
		                 row.partner, '\n')
	end

	-- FIXME: Can we assume that verbs without specified aspect are always
	-- perfective?
	out_stream:write('.SH ', row.aspect == "imperfective" and 'PRESENT\n' or 'FUTURE\n',
	                 map_accented("\\[u042F] "), map_accented(row.sg1), '.\n.br\n',
	                 map_accented("\\[u0422]\\[u044B] "), map_accented(row.sg2), '.\n.br\n',
	                 map_accented("\\[u041E]\\[u043D]/\\[u041E]\\[u043D]\\[u0430]'/\\[u041E]\\[u043D]\\[u043E]' "),
	                         map_accented(row.sg3), '.\n.br\n',
	                 map_accented("\\[u041C]\\[u044B] "), map_accented(row.pl1), '.\n.br\n',
	                 map_accented("\\[u0412]\\[u044B] "), map_accented(row.pl2), '.\n.br\n',
	                 map_accented("\\[u041E]\\[u043D]\\[u0438]' "), map_accented(row.pl3), '.\n.br\n')

	out_stream:write('.SH PAST\n',
	                 map_accented("\\[u041E]\\[u043D] "), map_accented(row.past_m), '.\n.br\n',
	                 map_accented("\\[u041E]\\[u043D]\\[u0430]' "), map_accented(row.past_f), '.\n.br\n',
	                 map_accented("\\[u041E]\\[u043D]\\[u043E]' "), map_accented(row.past_n), '.\n.br\n',
	                 map_accented("\\[u041E]\\[u043D]\\[u0438]' "), map_accented(row.past_pl), '.\n')

	-- FIXME: Is the singular/plural distinction always obvious?
	out_stream:write('.SH IMPERATIVE\n',
	                 map_accented(row.imperative_sg), '! / ',
	                 map_accented(row.imperative_pl), '!\n')
end

function format.other(word_id, accented)
	out_stream:write('.SH WORD\n',
	                 map_accented(accented), '\n')
end

local cur = assert(con:execute(string.format([[
	SELECT accented, type, words.id AS word_id
	FROM words WHERE bare = "%s"
]], search_word)))
local row = cur:fetch({}, "a")
cur:close()

if not row then
	io.stderr:write('Word "', search_word, '" not found!\n')
else
	local word_id = row.word_id
	local word_type = row.type or "other"
	-- FIXME: Some words (e.g. personal pronouns) apparently do not
	-- come with accents!?
	local word_accented = row.accented or search_word

	-- Open stream only now, after no more messages have to be written to
	-- stdout/stderr.
	out_stream = assert(use_stdout and io.stdout or io.popen("man /dev/stdin", "w"))

	out_stream:write('.\\" t\n',
	                 '.TH "', search_word, '" "', word_type, '"\n')

	--
	-- Word-specific sections
	--
	format[word_type](row.word_id, word_accented)

	--
	-- Generic sections
	--
	-- FIXME: Print other translations if primary
	-- language is not available
	cur = assert(con:execute(string.format([[
		SELECT tl FROM translations
		WHERE word_id = %d AND lang = "%s"
	]], word_id, lang)))
	row = cur:fetch({}, "a")
	if row then
		out_stream:write('.SH TRANSLATION\n')

		repeat
			out_stream:write(row.tl)
			row = cur:fetch({}, "a")
			if row then out_stream:write(', ') end
		until not row

		out_stream:write('\n')
	end
	cur:close()

	--
	-- NOTE: There can be many exampes, so print them last.
	--
	cur = assert(con:execute(string.format([[
		SELECT ru, start, length, tl
		FROM sentences_words JOIN sentences ON sentence_id = sentences.id
		WHERE word_id = %d AND lang = "%s"
	]], word_id, lang)))
	row = cur:fetch({}, "a")
	if row then
		out_stream:write('.SH EXAMPLES\n')

		repeat
			-- FIXME: Highlight search word in sentences.
			-- start/length are apparently in characters
			-- instead of bytes.
			--[[
			local ru_hl = row.ru:sub(1, row.start)..'\\fI'..
			              row.ru:sub(row.start+1, row.start+1+row.length)..'\\fP'..
			              row.ru:sub(row.start+1+row.length+1)
			]]
			out_stream:write('.TP\n',
			                 map_accented(row.ru), '\n',
			                 row.tl, '\n')
			row = cur:fetch({}, "a")
		until not row

	end
	cur:close()
end

con:close()
env:close()

if out_stream then out_stream:close() end
