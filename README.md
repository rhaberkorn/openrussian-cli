# An Offline Console Russian Dictionary (based on openrussian.org)

This is an offline console and terminal-friendly Russian dictionary,
based on the database of [openrussian.org](https://en.openrussian.org/).

* Works offline (without internet access) and is very fast.
  This really pays off if you browse Russian words a lot.
* It integrates well into the console environment - browse dictionary
  entries like man pages.
  Internally, Troff code is generated which makes further processing of generated
  pages ~~very easy~~ possible.
* Puts very low requirements on the runtime environment:
  a black and white terminal display is sufficient.
* Bash auto completions supported.
  Most of this is handled by the script's `-C` argument, so it
  is trivial to add support for other shells.
  Contributions are welcome!
* Search terms can be: base forms (infinitives, nominative singular nouns...),
  inflections (all cases, conjugations, short forms, imperatives...) and
  translations.
* Search terms are [glob patterns](https://en.wikipedia.org/wiki/Glob_(programming)),
  which is very useful for looking up words with uncertain spelling or finding
  related words.

Possible future features:

* Limit the number of results (by default to 1000) - the sheer number of results
  can slow down auto-completions.
* Not all terminals can display the accent correctly (linux console), so we should have
  a fallback.
  Ideally this can be detected, or we simply whitelist terminal emulators via $TERM.
* Better internationalization when generating German pages (`-Lde`).
* Lookups via popular
  [ASCII-cyrillic transliterations](https://en.wikipedia.org/wiki/Informal_romanizations_of_Cyrillic) -
  would be useful without a Russian/cyrillic keyboard layout.
* Be tolerant to typing mistakes.
* Accented characters are still broken in nroff tables
  (see https://lists.gnu.org/archive/html/groff/2018-08/msg00000.html).

## Installation

Build-time dependencies:

    sudo apt-get install make pkg-config lua5.2 bash-completion wget unzip gawk sqlite3

Run-time dependencies:

    sudo apt-get install lua5.2 lua-sql-sqlite3 man-db bash-completion

Furthermore, you will need the [luautf8 library](https://github.com/starwing/luautf8).
Using [LuaRocks](https://luarocks.org/), it may be installed as follows:

    sudo luarocks-5.2 install luautf8

Building is straight forward:

    make
    sudo make install

If you want to redownload the latest [openrussian.org](https://en.openrussian.org/)
database:

    make clean all check

**Warning:** While the database content might be newer, the database schema
might also at any time become incompatible with the existing script.
That is why a `check` is performed after building everything in the above
example.
If it returns lots of errors, you should probably stay with the original database.
Otherwise, the error messages might help in fixing/upgrading the script.
You are of course welcome to contribute patches. :-)

### Bash Aliases

While the default command name `openrussian` was chosen to avoid cluttering the
global command namespace, you may want to define more concise shortcuts.
In order to do so, add something like the following to your `~/.bashrc`:

    alias ru='openrussian' ру='openrussian'
    _completion_loader openrussian
    complete -F _openrussian_completions ru ру

This adds the alias `ru` (latin) and `ру` (cyrillic).
It would however be useful to add a few default options to the `ru` and `ру` aliases.
Unfortunately, above method cannot take that into account.
A more robust solution might be to install the
[complete-alias](https://github.com/cykerway/complete-alias) script and adding
something like the following to your `~/.bash_completion`:

    alias ru='openrussian -Lde -Len' ру='openrussian -Lde -Len'
    complete -F _complete_alias ru ру

## Examples

A simple lookup:

    openrussian саморазрушение

Display the German translation:

    openrussian -Lde саморазрушение

Display both German and English translations, giving precedence to German:

    openrussian -Lde -Len саморазрушение

If you are unsure which consonants appear in this word:

    openrussian самора[сз]ру[шщ]ение

Find more words derived from "разрушение":

    openrussian *разрушение

Avoid ambiguous search results:

    openrussian -V коса

Look up by translation:

    openrussian catch a cold

Graphical display using `groffer`:

    openrussian -p кошка | groffer -Kutf8 --mode pdf2

You may have to specify a non-default font supporting
cyrillic characters via groffer's `-f` option.

## License

The main program is licensed under the GNU General Public License Version 3 or later
(see `COPYING`).

This repository contains database dumps from the
[openrussian.org website](https://en.openrussian.org/dictionary).
The `openrussian-sql.zip` file is licensed under the [CC BY-SA](https://creativecommons.org/licenses/)
license.

This repository also contains code, imported from the
[mysql2sqlite repository](https://github.com/dumblob/mysql2sqlite.git).
The file `mysql2qlite` is licensed under the following terms and conditions:

```
The MIT License (MIT)

Copyright (c) 2015 esperlu, 2016 dumblob

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Further documentation

    man openrussian
