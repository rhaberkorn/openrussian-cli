function __fish_complete_openrussian
	set --local lang (commandline --current-process | string match --regex -- '-L..')
	set --local token (commandline --current-process --current-token)
	openrussian $lang -C $token 2>/dev/null
end

complete --command openrussian --arguments "-Len -Lde -V -p (__fish_complete_openrussian)"
