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

" Section: Misc {{{1

TLpredicate nil_QMARK_(val) a:val is# g:timl#nil
TLexpr blessing(val) timl#keyword#intern(timl#type#string(a:val))
TLalias meta timl#meta
TLalias with_meta timl#with_meta

" }}}1
" Section: Functions {{{1

let s:def = timl#symbol('def')
let s:lets = timl#symbol('let*')
let s:fns = timl#symbol('fn*')
let s:fn1 = timl#symbol('timl.core/fn')
let s:defn = timl#symbol('timl.core/defn')
let s:setq = timl#symbol('set!')
let s:dot = timl#symbol('.')
let s:form = timl#symbol('&form')
let s:env = timl#symbol('&env')

TLfunction fn(form, env, ...)
  return timl#with_meta(timl#cons#from_array([s:fns] + a:000), timl#meta(a:form))
endfunction
let g:timl#core#fn.macro = g:timl#true

TLfunction defn(form, env, name, ...)
  return timl#list(s:def, a:name, timl#with_meta(timl#cons#from_array([s:fn1, a:name] + a:000), timl#meta(a:form)))
endfunction
let g:timl#core#defn.macro = g:timl#true

TLfunction defmacro(form, env, name, params, ...)
  let extra = [s:form, s:env]
  if type(a:params) == type([])
    let body = [extra + a:params] + a:000
  else
    let _ = {}
    let body = []
    for _.list in [a:params] + a:000
      call add(body, timl#cons#create(extra + timl#first(_.list), timl#next(_.list)))
    endfor
  endif
  let fn = timl#symbol#gen('fn')
  return timl#list(s:lets,
        \ [fn, timl#cons#from_array([s:defn, a:name] + body)],
        \ timl#list(s:setq, timl#list(s:dot, fn, timl#symbol('macro')), 1),
        \ fn)
endfunction
let g:timl#core#defmacro.macro = g:timl#true

TLexpr identity(x) a:x

TLargfunction apply
  if len(a:_) < 2
    throw 'timl: arity error'
  endif
  let [F; args] = a:_
  let args = args[0:-2] + timl#ary(args[-1])
  return timl#call(F, args)
endfunction

" }}}1
" Section: Equality {{{1

TLpredicate _EQ_(...)     call('timl#equalp', a:000)
TLpredicate not_EQ_(...) !call('timl#equalp', a:000)

TLfunction! identical_QMARK_(x, ...) abort
  for y in a:000
    if a:x isnot# y
      return s:false
    endif
  endfor
  return s:true
endfunction

" }}}1

delcommand TLfunction
delcommand TLalias
delcommand TLexpr
delcommand TLpredicate
unlet s:dict

call timl#source_file(expand('<sfile>:r') . '_bootstrap.tim')

" vim:set et sw=2:
