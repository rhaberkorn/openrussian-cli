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
# generating the SQLITE database while we don't always re-download it.
# Effectively, it will behave like a temporary file.
.INTERMEDIATE: openrussian-sql.zip
openrussian-sql.zip:
	wget -O $@ 'https://en.openrussian.org/downloads/openrussian-sql.zip'

# NOTE: VACUUMing the database saves a few megabytes
openrussian-sqlite3.db : openrussian-sql.zip mysql2sqlite
	unzip -p $< openrussian.sql | ./mysql2sqlite - | sqlite3 $@
	sqlite3 $@ VACUUM

# NOTE: Installation of the Bash completions depends on the Debain bash-completion
# package being installed or something similar
install : openrussian openrussian-sqlite3.db openrussian-completion.bash
	mkdir -p $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(PREFIX)/share/openrussian
	install openrussian $(DESTDIR)$(PREFIX)/bin
	cp openrussian-sqlite3.db $(DESTDIR)$(PREFIX)/share/openrussian
	cp openrussian-completion.bash $(DESTDIR)$(COMPLETIONSDIR)/openrussian

clean:
	$(RM) -f openrussian openrussian-sql.zip openrussian-sqlite3.db
