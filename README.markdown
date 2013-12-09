# Welcome to the future (of the past)

TimL is a Lisp dialect implemented in and compiling down to VimL, the
scripting language provided by the Vim text editor.  Think Clojure meets VimL.

## Clojure similarities

* Lexical scope with closures.
* Namespaces, including `refer` and `alias`.  (Higher abstractions like the
  full `ns` macro don't exist yet, so you'll make do with these for now.)
* `timl.core`, a tiny but growing API resembling `clojure.core`.
* The same collection types and interfaces (although currently lacking many of
  the performance guarantees).
* Macros, including syntax quoting and the implicit `&form` and `&env`.
* Metadata (although a lack of proper `var`s eliminates several common
  use cases).
* Call a Vim command with `:`: `(: "wq")`.

## Clojure differences

Too many omissions to list, but:

* No reference types.  Most would be of limited use in a single threaded
  environment.
* Fuck `clojure.string/join`, that shit is in core.

## VimL interop

* TimL functions are actually VimL dictionaries (objects) containing a
  dictionary function (method) and a reference to the enclosing scope.
* Defining a symbol `baz` in namespace `foo.bar` actually defines
  `g:foo#bar#baz`.  If that symbol refers to something callable (like a
  function), calling `foo#bar#baz()` on the VimL side will invoke it.
* Arbitrary Vim variables and options can be referred to using VimL notation:
  `b:did_ftplugin`, `v:version`, `&expandtab`. You can also change them with
  `set!`: `(set! &filetype "timl")`.
* `#*function` returns a reference to a built-in or user defined function.
  You can call it like any other function: `(#*toupper "TimL Rocks!")`.

## Getting started

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tpope/timl.git

Once help tags have been generated, you can view the manual with
`:help timl`.  With pathogen.vim, generate help tags with `:Helptags`.

Start a repl with `:TLrepl`.  The first time may take several seconds (if your
computer is a piece of shit), but compilation is cached, so subsequent
invocations will be super quick, even if Vim is restarted.

You can use Clojure's `ns`, `in-ns`, `require`, `refer`, `alias`, and `use`,
but currently they are all limited to their single argument forms, so expect a
bit more legwork:

    (ns my.ns)
    (use 'timl.repl)
    (require 'timl.file)
    (alias 'file 'timl.file)

Put files in `autoload/*.tim` and they will be requirable.

See `:help timl` for the language specification, or [read it
online](https://github.com/tpope/timl/tree/master/doc).

## License

Copyright © Tim Pope.  Distributed under the same terms as Vim itself.  See
`:help license`.
