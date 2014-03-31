" Vim syntax file
" Language:     TimL
" Maintainer:   Tim Pope <code@tpope.net>
" Filenames:    *.timl

if exists("b:current_syntax")
  finish
endif

syntax sync minlines=100

if !exists('s:functions')
  let s:file = readfile(findfile('syntax/vim.vim', &rtp))
  let s:options = split(join(map(filter(copy(s:file), 'v:val =~# "^syn keyword vimOption contained\t[^in]"'), 'substitute(v:val, "^.*\t", "", "g")'), ' '), '\s\+')
  let s:functions = split(join(map(filter(copy(s:file), 'v:val =~# "^syn keyword vimFuncName contained\t[^in]"'), 'substitute(v:val, "^.*\t", "", "g")'), ' '), ' ')
endif

setl iskeyword+=?,!,#,$,%,&,*,+,.,/,<,>,:,=,45
let b:syntax_ns_str = timl#interactive#ns_for_cursor(0)
let b:syntax_vars = keys(timl#namespace#map(timl#namespace#find(b:syntax_ns_str)))

let b:current_syntax = "timl"

function! s:syn_keyword(group, keywords) abort
  if !empty(a:keywords)
    exe 'syntax keyword '.a:group.' '.join(a:keywords, ' ')
  endif
endfunction
call s:syn_keyword('timlSymbol', b:syntax_vars)
call s:syn_keyword('timlDefine', filter(copy(b:syntax_vars), 'v:val =~# "^def\\%(ault\\)\\@!"'))
syntax keyword timlSpecialParam & &form &env

syntax keyword timlConditional if
syntax keyword timlDefine def deftype* set! declare
syntax keyword timlRepeat loop recur
syntax keyword timlStatement do let fn . execute
syntax keyword timlSpecial let* fn* var function
syntax keyword timlException try catch finally throw

syntax keyword timlConstant nil
syntax keyword timlBoolean false true
syntax match timlKeyword ":\k\+"
syntax match timlCharacter "\\\%(space\|tab\|newline\|return\|formfeed\|backspace\|.\)"
syntax match timlNumber "\<[-+]\=0\o\+\>"
syntax match timlNumber "\<[-+]\=0x\x\+\>"
syntax match timlNumber "\<[-+]\=\%([1-9]\d*\|0\)\%(\.\d\+\)\=\%([Ee]\d\+\)\=\>"
syntax keyword timlNumber Infinity -Infinity +Infinity NaN
syntax region timlString start=/"/ skip=/\\\\\|\\"/ end=/"/ contains=timlStringEscape,@Spell
syntax match timlStringEscape "\v\\%([uU]\x{4}|[0-3]\o{2}|\o\{1,2}|[xX]\x{1,2}|[befnrt\\"]|\<[[:alnum:]-]+\>)" contained
syntax region timlRegexp start=/#"/ skip=/\\\\\|\\"/ end=/"/ contains=timlRegexpSpecial

syntax match timlFuncref "\<#\*" nextgroup=timlVimFunction
syntax match timlVarref "\<#'" nextgroup=timlSymbol
syntax match timlQuote "'"
syntax match timlSyntaxQuote "`"
syntax match timlUnquote "\~@\="
syntax match timlDeref "@"
syntax match timlMeta "\^"

syntax region timlList matchgroup=timlGroup start="(" end=")" contains=TOP,@Spell
syntax region timlVector matchgroup=timlGroup start="\[" end="]" contains=TOP,@Spell
syntax region timlMap matchgroup=timlGroup start="{" end="}" contains=TOP,@Spell
syntax region timlSet matchgroup=timlGroup start="#{" end="}" contains=TOP,@Spell
syntax region timlFn matchgroup=timlGroup start="#(" end=")" contains=TOP,@Spell
syntax match timlSymbol '\<%[1-9]\d*\>'
syntax match timlSymbol '\<%&\=\>'

syntax match timlComment "\<#_"
syntax match timlComment ";.*$"
syntax match timlComment ";= "
syntax match timlComment ";! " nextgroup=timlError
syntax match timlError ".*$" contained
syntax match timlComment "#!.*$"
syntax match timlComment ";;.*$" contains=@Spell

call s:syn_keyword('timlVimOption', map(copy(s:options), "'&'.v:val"))
call s:syn_keyword('timlVimOption', map(copy(s:options), "'&l:'.v:val"))
call s:syn_keyword('timlVimOption', map(copy(s:options), "'&g:'.v:val"))
exe 'syn match timlVimFunction contained "\%('.join(s:functions, '\|').'\)\>"'
syntax match timlVar '\<[glabwtv]:\k\+\>'

hi def link timlDefine Define
hi def link timlSymbol Identifier
hi def link timlSpecialParam Special
hi def link timlConditional Conditional
hi def link timlRepeat Repeat
hi def link timlStatement Statement
hi def link timlException Exception
hi def link timlBoolean Boolean
hi def link timlConstant Constant
hi def link timlKeyword Constant
hi def link timlCharacter Character
hi def link timlString String
hi def link timlRegexp String
hi def link timlStringEscape Special
hi def link timlRegexpSpecial Special
hi def link timlNumber Number
hi def link timlSpecial Special
hi def link timlFuncref Special
hi def link timlVarref Special
hi def link timlQuote Special
hi def link timlSyntaxQuote Special
hi def link timlUnquote Special
hi def link timlDeref Special
hi def link timlMeta Special
hi def link timlGroup Special
hi def link timlComment Comment
hi def link timlError WarningMsg

hi def link timlVimFunction Function
hi def link timlVimOption Type

" vim:set et sw=2:
