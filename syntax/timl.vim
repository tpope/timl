" Vim syntax file
" Language:     TimL
" Maintainer:   Tim Pope <code@tpope.net>
" Filenames:    *.timl

if exists("b:current_syntax")
  finish
endif

if !exists('s:functions')
  let s:file = readfile(findfile('syntax/vim.vim', &rtp))
  let s:options = split(join(map(filter(copy(s:file), 'v:val =~# "^syn keyword vimOption contained\t[^in]"'), 'substitute(v:val, "^.*\t", "", "g")'), ' '), ' ')
  let s:functions = split(join(map(filter(copy(s:file), 'v:val =~# "^syn keyword vimFuncName contained\t[^in]"'), 'substitute(v:val, "^.*\t", "", "g")'), ' '), ' ')
endif

runtime! syntax/clojure.vim
setl iskeyword+=?,!,#,$,%,&,*,+,.,/,<,>,:,=,45
let b:syntax_ns_str = timl#ns_for_cursor(0)
let b:syntax_vars = keys(timl#namespace#find(b:syntax_ns_str).mappings)

let b:current_syntax = "timl"

function! s:syn_keyword(group, keywords)
  if !empty(a:keywords)
    exe 'syn keyword '.a:group.' '.join(a:keywords, ' ')
  endif
endfunction
call s:syn_keyword('timlSymbol', b:syntax_vars)
call s:syn_keyword('timlDefine', filter(copy(b:syntax_vars), 'v:val =~# "^def\\%(ault\\)\\@!"'))

syntax keyword timlConstant nil
syntax keyword timlBoolean false true
syn match timlFuncref "#\*" nextgroup=timlVimFunction
syntax region timlString start=/"/ skip=/\\\\\|\\"/ end=/"/ contains=timlStringEscape,@Spell
syntax match timlStringEscape "\v\\%([uU]\x{4}|[0-3]\o{2}|\o\{1,2}|[xX]\x{1,2}|[befnrt\\"]|\<[[:alnum:]-]+\>)" contained
syn keyword timlConditional if
syn keyword timlDefine set!
syn keyword timlRepeat loop recur
syn keyword timlStatement do let fn . :
syn keyword timlException try catch finally throw

call s:syn_keyword('timlVimOption', map(copy(s:options), "'&'.v:val"))
call s:syn_keyword('timlVimOption', map(copy(s:options), "'&l:'.v:val"))
call s:syn_keyword('timlVimOption', map(copy(s:options), "'&g:'.v:val"))
exe 'syn match timlVimFunction contained "\%('.join(s:functions, '\|').'\)\>"'

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

hi def link timlVimFunction Function
hi def link timlVimOption Type

" vim:set et sw=2:
