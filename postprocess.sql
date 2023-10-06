-- Drop unused tables, hopefully saving a few megabytes.
-- `expressions_words` is for excercises???
DROP TABLE expressions_words;
-- `categories_words2` references `categories` but is not in the database!?
DROP TABLE categories_words2;

-- This table is especially added to aid lookups and autocompletions on all
-- possible inflections.
-- This is significantly faster than using the existing tables.
--
-- FIXME: Some of the columns contain multiple comma-separated values
-- (sometimes in braces), so we probably need a Lua script for initializion.
-- TODO: Translations should probably be in this table, or a separate one as well.
-- But see above.
CREATE TABLE bare_inflections (`word_id` INTEGER NOT NULL, `bare` VARCHAR(100) NOT NULL COLLATE BINARY);
-- Indexing the `bare` column allows ultra-fast lookups even via GLOB
-- in most common cases. For this optimization to work, the column must
-- also be BINARY collated. See also:
-- https://www.sqlite.org/optoverview.html#the_like_optimization
CREATE INDEX idx_bare_inflections_bare ON bare_inflections (`bare`);
INSERT INTO bare_inflections SELECT word_id, REPLACE(temp, '''', '') AS bare
FROM (
	-- Search word might be a noun or adjective declension
	SELECT word_id, nom AS temp FROM declensions
	UNION ALL
	SELECT word_id, gen AS temp FROM declensions
	UNION ALL
	SELECT word_id, dat AS temp FROM declensions
	UNION ALL
	SELECT word_id, acc AS temp FROM declensions
	UNION ALL
	SELECT word_id, inst AS temp FROM declensions
	UNION ALL
	SELECT word_id, prep AS temp FROM declensions
	UNION ALL
	-- Search word might be a special adjective inflection
	SELECT word_id, comparative AS temp FROM adjectives
	UNION ALL
	SELECT word_id, superlative AS temp FROM adjectives
	UNION ALL
	SELECT word_id, short_m AS temp FROM adjectives
	UNION ALL
	SELECT word_id, short_f AS temp FROM adjectives
	UNION ALL
	SELECT word_id, short_n AS temp FROM adjectives
	UNION ALL
	SELECT word_id, short_pl AS temp FROM adjectives
	UNION ALL
	-- Search word might be a verb imperative or past form
	SELECT word_id, imperative_sg AS temp FROM verbs
	UNION ALL
	SELECT word_id, imperative_pl AS temp FROM verbs
	UNION ALL
	SELECT word_id, past_m AS temp FROM verbs
	UNION ALL
	SELECT word_id, past_f AS temp FROM verbs
	UNION ALL
	SELECT word_id, past_n AS temp FROM verbs
	UNION ALL
	SELECT word_id, past_pl AS temp FROM verbs
	UNION ALL
	-- Search word might be a verb conjugation
	SELECT word_id, sg1 AS temp FROM conjugations
	UNION ALL
	SELECT word_id, sg2 AS temp FROM conjugations
	UNION ALL
	SELECT word_id, sg3 AS temp FROM conjugations
	UNION ALL
	SELECT word_id, pl1 AS temp FROM conjugations
	UNION ALL
	SELECT word_id, pl2 AS temp FROM conjugations
	UNION ALL
	SELECT word_id, pl3 AS temp FROM conjugations
)
WHERE bare <> '';

-- Saves a few megabytes
VACUUM;
