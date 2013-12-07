" Vim syntax file
" Language:     TimL
" Maintainer:   Tim Pope <code@tpope.net>
" Filenames:    *.timl

if exists("b:current_syntax")
  finish
endif

runtime! syntax/clojure.vim
setl iskeyword+=?,!,#,$,%,&,*,+,.,/,<,>,:,=,45
let b:syntax_ns = timl#ns_for_cursor(0)
let b:syntax_vars = keys(timl#reflect#ns_var_completion(b:syntax_ns))

let b:current_syntax = "timl"

exe 'syn keyword timlSymbol '.join(b:syntax_vars, ' ')
exe 'syn keyword timlDefine '.join(filter(copy(b:syntax_vars), 'v:val =~# "^def\\%(ault\\)\\@!"'), ' ')

syntax keyword timlConstant nil
syntax keyword timlBoolean false true
syn match timlFuncref "#\*" nextgroup=vimFuncName
syntax region timlString start=/"/ skip=/\\\\\|\\"/ end=/"/ contains=timlStringEscape,@Spell
syntax match timlStringEscape "\v\\%([uU]\x{4}|[0-3]\o{2}|\o\{1,2}|[xX]\x{1,2}|[befnrt\\"]|\<[[:alnum:]-]+\>)" contained
syn keyword timlConditional if
syn keyword timlDefine set!
syn keyword timlRepeat loop recur
syn keyword timlStatement do let fn . :
syn keyword timlException try catch finally throw

hi def link timlDefine Define
hi def link timlSymbol Identifier
hi def link timlBoolean Boolean
hi def link timlConstant Constant
hi def link timlString String
hi def link timlStringEscape Special
hi def link timlFuncref Special
hi def link timlConditional Conditional
hi def link timlRepeat Repeat
hi def link timlStatement Statement
hi def link timlException Exception

" vim:set et sw=2:
