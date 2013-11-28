" Vim syntax file
" Language:     TimL
" Maintainer:   Tim Pope <code@tpope.net>
" Filenames:    *.timl

if exists("b:current_syntax")
  finish
endif

runtime! syntax/lisp.vim

setl iskeyword+=?,!,#,$,%,&,*,+,.,/,<,>,:,~

syn cluster lispBaseListCluster add=timlSpecialForm,timlString

syn keyword timlSpecialForm quote quasiquote unquote unquote-splicing function
syn keyword timlSpecialForm if setq defvar defun defmacro lambda let do
syn keyword timlSpecialForm try catch finally
syn region  timlString   start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match   timlComment  ";.*"

hi def link timlSpecialForm       PreProc
hi def link timlComment           Comment
hi def link timlString            String

let b:current_syntax = "timl"

" vim:set et sw=2:
