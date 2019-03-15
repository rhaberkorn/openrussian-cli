#/bin/bash

# NOTE: Uses SQL for matching instead of compgen, since it's probably not
# a good idea to always retrieve all the words, although this happens anyway
# when completing an empty word.
#
# FIXME: sqlite3 command-line tool does not provide a safe method for embedding
# strings, so we should either properly escape $2 or write an external Lua script.

_openrussian_completions()
{
	SQL="SELECT bare FROM words WHERE bare LIKE \"$2%\""

	# Calculate database path based on the installation path of the `openrussian`
	# CLI tool. This way, we can avoid preprocessing the script during installation.
	PREFIX=$(dirname $(which openrussian))/..

	COMPREPLY=($(sqlite3 "$PREFIX/share/openrussian/openrussian-sqlite3.db" "$SQL"))
}

complete -F _openrussian_completions openrussian
