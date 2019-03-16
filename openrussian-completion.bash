#/bin/bash

# NOTE: Uses SQL for matching instead of compgen, since it's probably not
# a good idea to always retrieve all the words, although this happens anyway
# when completing an empty word.

_openrussian_completions()
{
	# NOTE: sqlite3's command-line tool does not provide a way to properly
	# embed strings, so we try to escape it here.
	WORD=$(echo -n "$2" | sed 's/"/""/g')

	# This is a rather convoluted way of writing
	# SELECT bare FROM words WHERE bare LIKE "${WORD}%";
	# but allowing $WORD to contain accentuation characters, which can easily
	# happen when cutting/pasting words from the openrussian.lua manpages or the
	# internet.
	# NOTE: This is merely a workaround since all completions will begin with
	# $WORD including accents and end without accents, so the suggested completions
	# will likely be with wrong accents.
	# It seems to be impossible, at least in Bash, to rubout $WORD first.
	SQL=$(printf 'SELECT "%s" || SUBSTR(bare, LENGTH(REPLACE("%s", "\u0301", ""))+1)
	              FROM words WHERE bare LIKE REPLACE("%s%%", "\u0301", "")' \
	             "$WORD" "$WORD" "$WORD")

	# Calculate database path based on the installation path of the `openrussian`
	# CLI tool. This way, we can avoid preprocessing the script during installation.
	PREFIX=$(dirname $(which openrussian))/..

	COMPREPLY=($(sqlite3 "$PREFIX/share/openrussian/openrussian-sqlite3.db" "$SQL"))
}

complete -F _openrussian_completions openrussian
