" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl")
  finish
endif
let g:autoloaded_timl = 1

" Section: Util {{{1

function! timl#truth(val) abort
  return a:val isnot# g:timl#nil && a:val isnot# g:timl#false
endfunction

function! timl#keyword(str) abort
  return timl#keyword#intern(a:str)
endfunction

function! timl#symbol(str) abort
  return timl#symbol#intern(a:str)
endfunction

" }}}1
" Section: Lists {{{1

function! timl#seq(coll) abort
  return timl#coll#seq(a:coll)
endfunction

function! timl#first(coll) abort
  return timl#coll#first(a:coll)
endfunction

function! timl#rest(coll) abort
  return timl#coll#rest(a:coll)
endfunction

function! timl#next(coll) abort
  return timl#coll#seq(timl#coll#rest(rest))
endfunction

function! timl#list(...) abort
  return timl#list#create(a:000)
endfunction

" }}}1
" Section: Invocation {{{1

function! timl#call(Func, args, ...) abort
  if type(a:Func) == type(function('tr'))
    return call(a:Func, a:args, a:0 ? a:1 : {})
  else
    return a:Func.__call__(a:args)
  endif
endfunction

function! timl#invoke(Func, ...) abort
  if type(a:Func) == type(function('tr'))
    return call(a:Func, a:000, {})
  else
    return a:Func.__call__(a:000)
  endif
endfunction

" }}}1
" Section: Evaluation {{{1

function! timl#eval(x) abort
  return timl#loader#eval(a:x)
endfunction

function! timl#re(str) abort
  return timl#eval(timl#reader#read_string(a:str))
endfunction

function! timl#rep(str) abort
  return timl#printer#string(timl#re(a:str))
endfunction

" }}}1

runtime! autoload/timl/bootstrap.vim

" vim:set et sw=2:
