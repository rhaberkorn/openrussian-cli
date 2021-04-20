PREFIX ?= /usr/local

LUA ?= lua5.2
LUAC ?= luac5.2

COMPLETIONSDIR ?= $(shell pkg-config --variable=completionsdir bash-completion)

all : openrussian openrussian-sqlite3.db

openrussian : openrussian.lua
	echo "#!$(shell which $(LUA))" >$@
	$(LUAC) -o - $< >>$@
	chmod a+x $@

# Marking the ZIP intermediate makes sure it is automatically deleted after
# generating the SQLite database while we don't always re-download it.
# Effectively, it will behave like a temporary file.
# NOTE: This is disabled for the time being since the database schema changes
# from time to time, so a rebuild could easily break the script.
# Instead, we add the file to Git, so every clone is guaranteed to contain
# a database matching the openrussian.lua script.
#.INTERMEDIATE: openrussian-sql.zip
openrussian-sql.zip:
	wget -O $@ 'https://api.openrussian.org/downloads/openrussian-sql.zip'

openrussian-sqlite3.db : openrussian-sql.zip mysql2sqlite postprocess.sql
	$(RM) $@
	unzip -p $< openrussian.sql | awk -f ./mysql2sqlite - | sqlite3 $@
	sqlite3 $@ -batch <postprocess.sql

# Try to generate all possible pages
check : openrussian-sqlite3.db openrussian
	sqlite3 $< 'SELECT bare FROM words WHERE LIKELY(disabled = 0)' | \
	while read -r bare; do \
		./openrussian -V -p "$$bare" </dev/null >/dev/null || \
		echo "Error generating \"$$bare\"" >/dev/stderr; \
	done

# NOTE: Installation of the Bash completions depends on the Debain bash-completion
# package being installed or something similar
install : openrussian openrussian-sqlite3.db \
          openrussian-completion.bash openrussian.1
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	install openrussian $(DESTDIR)$(PREFIX)/bin
	mkdir -p $(DESTDIR)$(PREFIX)/share/openrussian
	cp openrussian-sqlite3.db $(DESTDIR)$(PREFIX)/share/openrussian
	cp openrussian-completion.bash $(DESTDIR)$(COMPLETIONSDIR)/openrussian
	mkdir -p $(DESTDIR)$(PREFIX)/man/man1
	cp openrussian.1 $(DESTDIR)$(PREFIX)/man/man1
	mandb

clean:
	$(RM) openrussian openrussian-sqlite3.db

.PHONY: all check install clean
