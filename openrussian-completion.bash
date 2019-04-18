#/bin/bash

_openrussian_completions()
{
	# Autocompletion of all search terms can be outsourced
	# to the openrussian.lua script, which has the advantage
	# of taking all command line flags into account.
	#
	# NOTE: mapfile is used to properly capture lines containing
	# whitespace
	# FIXME: Does not work if the last token contains spaces
	# FIXME: Also fails when trying to complete multiple tokens
	# (in order to avoid white-space quoting).
	mapfile -t COMPREPLY < <(openrussian -C "${COMP_WORDS[@]:1}" 2>/dev/null)

	# NOTE: openrussian.lua currently does not complete switch-names.
	COMPREPLY+=($(compgen -W "-Len -Lde -V -p" -- "$2"))
}

complete -F _openrussian_completions openrussian
