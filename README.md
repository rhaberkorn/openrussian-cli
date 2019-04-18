# An Offline Console Russian Dictionary (based on openrussian.org)

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

* Bilingual modes (German and English translations on the same generated page)
  to increase the amount of information if you happen to speak both of these languages.
* Better internationalization when generating German pages (`-Lde`).
* Lookups via popular ASCII-cyrillic transliterations - would be useful without
  a Russian/cyrillic keyboard layout.
* Be tolerant to typing mistakes.
* Accented characters are still broken in nroff tables
  (see https://lists.gnu.org/archive/html/groff/2018-08/msg00000.html).

## Installation

Build-time dependencies:

    sudo apt-get install make pkg-config lua5.2 bash-completion wget unzip gawk sqlite3

Run-time dependencies:

    sudo apt-get install lua5.2 lua-sql-sqlite3 man-db bash-completion

Furthermore, you will need the [luautf8 library](https://github.com/starwing/luautf8).
Using luarocks, it may be installed as follows:

    sudo luarocks-5.2 install luautf8

Building is straight forward:

    make
    sudo make install

If you want to redownload the latest [openrussian.org](https://en.openrussian.org/)
database:

    make clean all

**Warning:** While the database content might be newer, the database schema
might also at any time become incompatible with the existing script.
But you are of course welcome to contribute fixes/updates. :-)

## Examples

    openrussian саморазрушение
    openrussian -Lde саморазрушение
    openrussian самора[сз]рушение
    openrussian *разрушение
    openrussian -V коса
    openrussian catch a cold

Graphical display using `groffer`:

    openrussian -p кошка | groffer -Kutf8 --mode pdf2 -fSTIX

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
