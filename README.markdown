# TimL

Lisp implementation in pure Vim, yo.

Start a repl with `:TLrepl`.

Put files in `autoload/*.tim` and they will be automatically loaded into the
corresponding namespace.

See `:help timl` for the language specification, or [read it
online](https://github.com/tpope/timl/tree/master/doc).

## Installation

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tpope/timl.git

Once help tags have been generated, you can view the manual with
`:help timl`.  With pathgen.vim, generate help tags with `:Helptags`.

## License

Copyright © Tim Pope.  Distributed under the same terms as Vim itself.  See
`:help license`.
