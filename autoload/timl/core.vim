if exists("g:autoloaded_timl_core") || &cp || v:version < 700
  finish
endif
let g:autoloaded_timl_core = 1

let s:true = g:timl#true
let s:false = g:timl#false

let s:dict = {}

if !exists('g:timl_functions')
  let g:timl_functions = {}
endif

let s:ns = timl#namespace#find(timl#symbol('timl.core'))

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

function! s:call(...) dict
  return self.apply(a:000)
endfunction

function! s:apply(_) dict
  return call(self.call, a:_, self)
endfunction

command! -bang -nargs=1 TLargfunction
      \ let g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')} = timl#bless('timl.lang/Function', {
      \    'ns': s:ns,
      \    'name': timl#symbol(timl#demunge(matchstr(<q-args>, '^\zs[[:alnum:]_]\+'))),
      \    'call': s:function('s:call')}) |
      \ function! g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')}.apply(_) abort

command! -bang -nargs=1 TLfunction
      \ let g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')} = timl#bless('timl.lang/Function', {
      \    'ns': s:ns,
      \    'name': timl#symbol(timl#demunge(matchstr(<q-args>, '^\zs[[:alnum:]_]\+'))),
      \    'apply': s:function('s:apply'),
      \    'call': function('timl#core#'.matchstr(<q-args>, '^[[:alnum:]_#]\+'))}) |
      \ function! timl#core#<args> abort

command! -bang -nargs=+ TLalias
      \ let g:timl#core#{[<f-args>][0]} = timl#bless('timl.lang/Function', {
      \    'ns': s:ns,
      \    'name': timl#symbol(timl#demunge(([<f-args>][0]))),
      \    'apply': s:function('s:apply'),
      \    'call': function([<f-args>][1])})

command! -bang -nargs=1 TLexpr
      \ exe "function! s:dict.call".matchstr(<q-args>, '([^)]*)')." abort\nreturn".matchstr(<q-args>, ')\zs.*')."\nendfunction" |
      \ let g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')} = timl#bless('timl.lang/Function', {
      \    'ns': s:ns,
      \    'name': timl#symbol(timl#demunge(matchstr(<q-args>, '^\zs[[:alnum:]_]\+'))),
      \    'apply': s:function('s:apply'),
      \    'call': s:dict.call}) |
      \ let g:timl_functions[join([s:dict.call])] = {'file': expand('<sfile>'), 'line': expand('<slnum>')}

command! -bang -nargs=1 TLpredicate TLexpr <args> ? s:true : s:false

delcommand TLfunction
delcommand TLalias
delcommand TLexpr
delcommand TLpredicate
unlet s:dict

call timl#source_file(expand('<sfile>:r') . '_bootstrap.tim')

" vim:set et sw=2:
