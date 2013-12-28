" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl")
  finish
endif
let g:autoloaded_timl = 1

" Section: Util {{{1

function! timl#freeze(...) abort
  return a:000
endfunction

function! timl#truth(val) abort
  return a:val isnot# g:timl#nil && a:val isnot# g:timl#false
endfunction

function! timl#keyword(str)
  return timl#keyword#intern(a:str)
endfunction

function! timl#symbol(str)
  return timl#symbol#intern(a:str)
endfunction

" }}}1
" Section: Munging {{{1

" From clojure/lang/Compiler.java
let s:munge = {
      \ '.': "#",
      \ ',': "_COMMA_",
      \ ':': "_COLON_",
      \ '+': "_PLUS_",
      \ '>': "_GT_",
      \ '<': "_LT_",
      \ '=': "_EQ_",
      \ '~': "_TILDE_",
      \ '!': "_BANG_",
      \ '@': "_CIRCA_",
      \ "'": "_SINGLEQUOTE_",
      \ '"': "_DOUBLEQUOTE_",
      \ '%': "_PERCENT_",
      \ '^': "_CARET_",
      \ '&': "_AMPERSAND_",
      \ '*': "_STAR_",
      \ '|': "_BAR_",
      \ '{': "_LBRACE_",
      \ '}': "_RBRACE_",
      \ '[': "_LBRACK_",
      \ ']': "_RBRACK_",
      \ '/': "_SLASH_",
      \ '\\': "_BSLASH_",
      \ '?': "_QMARK_"}

let s:demunge = {}
for s:key in keys(s:munge)
  let s:demunge[s:munge[s:key]] = s:key
endfor
unlet! s:key

function! timl#munge(var) abort
  let var = type(a:var) == type('') ? a:var : a:var[0]
  return tr(substitute(substitute(var, '[^[:alnum:]:#_-]', '\=get(s:munge,submatch(0), submatch(0))', 'g'), '_SLASH_\ze.', '#', ''), '-', '_')
endfunction

function! timl#demunge(var) abort
  let var = type(a:var) == type('') ? a:var : a:var[0]
  return tr(substitute(var, '_\(\u\+\)_', '\=get(s:demunge, submatch(0), submatch(0))', 'g'), '_', '-')
endfunction

" }}}1
" Section: Type System {{{1

if !exists('g:timl#nil')
  let g:timl#nil = timl#freeze()
  lockvar 1 g:timl#nil
endif

function! timl#bless(class, ...) abort
  return timl#type#bless(a:class, a:0 ? a:1 : {})
endfunction

function! timl#type(val) abort
  return timl#type#string(a:val)
endfunction

function! timl#meta(obj) abort
  return timl#invoke(g:timl#core#meta, a:obj)
endfunction

function! timl#with_meta(obj, meta) abort
  return timl#invoke(g:timl#core#with_meta, a:obj, a:meta)
endfunction

function! timl#str(val) abort
  if type(a:val) == type('')
    return a:val
  elseif type(a:val) == type(0) || type(a:val) == 5
    return ''.a:val
  elseif type(a:val) == type(function('tr'))
    return substitute(join([a:val]), '[{}]', '', 'g')
  elseif timl#symbol#test(a:val) || timl#keyword#test(a:val)
    return a:val[0]
  elseif type(a:val) == type([])
    return join(map(copy(a:val), 'timl#str(v:val)'), ',').','
  else
    return '#<'.timl#type#string(a:val).'>'
  endif
endfunction

function! timl#equalp(x, y) abort
  return timl#invoke(g:timl#core#equiv, a:x, a:y) is# g:timl#true
endfunction

" }}}1
" Section: Collections {{{1

function! timl#mapp(coll)
  return timl#type#canp(a:coll, g:timl#core#dissoc)
endfunction

function! timl#setp(coll)
  return timl#type#canp(a:coll, g:timl#core#disj)
endfunction

function! timl#set(seq) abort
  return timl#set#coerce(a:seq)
endfunction

" }}}1
" Section: Lists {{{1

let s:ary = type([])

function! timl#seq(coll) abort
  return timl#invoke(g:timl#core#seq, a:coll)
endfunction

function! timl#emptyp(seq) abort
  return timl#seq(a:seq) is# g:timl#nil
endfunction

function! timl#seqp(coll) abort
  return timl#type#canp(a:coll, g:timl#core#seq)
endfunction

function! timl#first(coll) abort
  if timl#cons#test(a:coll)
    return a:coll.car
  elseif type(a:coll) == s:ary
    return get(a:coll, 0, g:timl#nil)
  else
    return timl#invoke(g:timl#core#first, a:coll)
  endif
endfunction

function! timl#rest(coll) abort
  if timl#cons#test(a:coll)
    return a:coll.cdr
  elseif timl#type#canp(a:coll, g:timl#core#more)
    return timl#invoke(g:timl#core#more, a:coll)
  else
    return timl#invoke(g:timl#core#more, timl#seq(a:coll))
  endif
endfunction

function! timl#next(coll) abort
  let rest = timl#rest(a:coll)
  return timl#seq(rest)
endfunction

function! timl#ffirst(seq) abort
  return timl#first(timl#first(a:seq))
endfunction

function! timl#fnext(seq) abort
  return timl#first(timl#next(a:seq))
endfunction

function! timl#nfirst(seq) abort
  return timl#next(timl#first(a:seq))
endfunction

function! timl#nnext(seq) abort
  return timl#next(timl#next(a:seq))
endfunction

function! timl#list(...) abort
  return timl#list#create(a:000)
endfunction

function! timl#ary(coll) abort
  return timl#array#coerce(a:coll)
endfunction

function! timl#vec(coll) abort
  return timl#vector#coerce(a:coll)
endfunction

function! timl#vector(...) abort
  return timl#vec(a:000)
endfunction

function! timl#vectorp(obj) abort
  return timl#type#canp(a:obj, g:timl#core#nth)
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
