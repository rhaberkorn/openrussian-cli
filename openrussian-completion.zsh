#compdef openrussian

# FIXME: If supported by `-C`, we could even show translations in the completions'
# help strings.
_get_terms() {
	compadd "${(@f)"$(openrussian -C "$words[-1]" 2>/dev/null)"}"
}

_arguments '-Len[Generate English translations]' '-Lde[Generate German translations]' \
           '-V[Verbatim matching (no case folding and inflections)]' \
           '-p[Print Troff code to stdout]' \
           '*:term:_get_terms'
