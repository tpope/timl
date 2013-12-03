" Vim syntax file
" Language:     TimL
" Maintainer:   Tim Pope <code@tpope.net>
" Filenames:    *.timl

if exists("b:current_syntax")
  finish
endif

runtime! syntax/clojure.vim
setl iskeyword+=?,!,#,$,%,&,*,+,.,/,<,>,:,=,45

let b:current_syntax = "timl"

" vim:set et sw=2:
