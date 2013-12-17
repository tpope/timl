" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl")
  finish
endif
let g:autoloaded_timl = 1

" Section: Util {{{1

function! s:funcname(name) abort
  return substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),'')
endfunction

function! s:function(name) abort
  return function(s:funcname(a:name))
endfunction

function! timl#freeze(...) abort
  return a:000
endfunction

function! timl#truth(val) abort
  return a:val isnot# g:timl#nil && a:val isnot# g:timl#false
endfunction

function! timl#key(key)
  if type(a:key) == type(0)
    return string(a:key)
  elseif timl#keyword#test(a:key)
    return a:key[0]
  elseif a:key is# g:timl#nil
    return ' '
  else
    return ' '.timl#printer#string(a:key)
  endif
endfunction

function! timl#dekey(key)
  if a:key =~# '^#'
    throw 'timl: invalid key '.a:key
  elseif a:key ==# ' '
    return g:timl#nil
  elseif a:key =~# '^ '
    return timl#reader#read_string(a:key[1:-1])
  elseif a:key =~# '^[-+]\=\d'
    return timl#reader#read_string(a:key)
  else
    return timl#keyword(a:key)
  endif
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
  return timl#type#dispatch(g:timl#core#meta, a:obj)
endfunction

function! timl#with_meta(obj, meta) abort
  return timl#type#dispatch(g:timl#core#with_meta, a:obj, a:meta)
endfunction

function! timl#str(val) abort
  if type(a:val) == type('')
    return a:val
  elseif type(a:val) == type(function('tr'))
    return substitute(join([a:val]), '[{}]', '', 'g')
  elseif timl#symbol#test(a:val) || timl#keyword#test(a:val)
    return a:val[0]
  elseif type(a:val) == type([])
    return join(map(copy(a:val), 'timl#str(v:val)'), ',').','
  else
    return string(a:val)
  endif
endfunction

function! timl#equalp(x, y) abort
  return timl#type#dispatch(g:timl#core#equal_QMARK_, a:x, a:y) is# g:timl#true
endfunction

" }}}1
" Section: Collections {{{1

function! timl#collp(coll) abort
  return timl#type#canp(a:coll, g:timl#core#conj)
endfunction

function! timl#into(coll, seq) abort
  let t = timl#type#string(a:coll)
  if timl#type#canp(a:coll, g:timl#core#transient)
    let _ = {'coll': timl#type#dispatch(g:timl#core#transient, a:coll), 'seq': timl#seq(a:seq)}
    while _.seq isnot# g:timl#nil
      let _.coll = timl#type#dispatch(g:timl#core#conj_BANG_, _.coll, timl#first(_.seq))
      let _.seq = timl#next(_.seq)
    endwhile
    return timl#type#dispatch(g:timl#core#persistent_BANG_, _.coll)
  else
    let _ = {'coll': a:coll, 'seq': timl#seq(a:seq)}
    while _.seq isnot# g:timl#nil
      let _.coll = timl#type#dispatch(g:timl#core#conj, _.coll, timl#first(_.seq))
      let _.seq = timl#next(_.seq)
    endwhile
    return _.coll
  endif
endfunction

function! timl#count(counted) abort
  return timl#type#dispatch(g:timl#core#count, a:counted)
endfunction

function! timl#containsp(coll, val) abort
  let sentinel = {}
  return timl#get(a:coll, a:val, sentinel) isnot# sentinel
endfunction

function! timl#mapp(coll)
  return timl#type#canp(a:coll, g:timl#core#dissoc)
endfunction

function! timl#setp(coll)
  return timl#type#canp(a:coll, g:timl#core#disj)
endfunction

function! timl#dictp(coll)
  return timl#type#string(a:coll) ==# 'vim/Dictionary'
endfunction

function! timl#set(seq) abort
  return timl#set#coerce(a:seq)
endfunction

function! timl#reduce(f, coll, ...) abort
  let _ = {}
  if a:0
    let _.val = a:coll
    let _.seq = timl#seq(a:1)
  else
    let _.seq = timl#seq(a:coll)
    if empty(_.seq)
      return g:timl#nil
    endif
    let _.val = timl#first(_.seq)
    let _.seq = timl#rest(_.seq)
  endif
  while _.seq isnot# g:timl#nil
    let _.val = timl#call(a:f, [_.val, timl#first(_.seq)])
    let _.seq = timl#next(_.seq)
  endwhile
  return _.val
endfunction

" }}}1
" Section: Lists {{{1

let s:cons = timl#type#intern('timl.lang/Cons')

let s:ary = type([])

function! timl#seq(coll) abort
  return timl#type#dispatch(g:timl#core#seq, a:coll)
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
    return timl#type#dispatch(g:timl#core#first, a:coll)
  endif
endfunction

function! timl#rest(coll) abort
  if timl#cons#test(a:coll)
    return a:coll.cdr
  elseif timl#type#canp(a:coll, g:timl#core#more)
    return timl#type#dispatch(g:timl#core#more, a:coll)
  else
    return timl#type#dispatch(g:timl#core#more, timl#seq(a:coll))
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

function! timl#get(coll, key, ...) abort
  return timl#type#dispatch(g:timl#core#lookup, a:coll, a:key, a:0 ? a:1 : g:timl#nil)
endfunction

function! timl#list(...) abort
  return timl#cons#from_array(a:000)
endfunction

function! timl#ary(coll) abort
  return timl#array#coerce(a:coll)
endfunction

function! timl#vec(coll) abort
  if type(a:coll) == type([])
    let vec = copy(a:coll)
  else
    let vec = timl#array#coerce(a:coll)
  endif
  return timl#array#lock(vec)
endfunction

function! timl#vector(...) abort
  return timl#vec(a:000)
endfunction

function! timl#vectorp(obj) abort
  return type(a:obj) == type([]) && a:obj isnot# g:timl#nil
endfunction

" }}}1
" Section: Eval {{{1

let s:function_tag = timl#keyword('#timl.lang/Function')
let s:multifn_tag = timl#keyword('#timl.lang/MultiFn')
function! timl#call(Func, args, ...) abort
  if type(a:Func) == type(function('tr'))
    return call(a:Func, a:args, a:0 ? a:1 : {})
  elseif type(a:Func) == type({}) && get(a:Func, '#tag') is# s:function_tag
    return a:Func.apply(a:args)
  elseif type(a:Func) == type({}) && get(a:Func, '#tag') is# s:multifn_tag
    return call('timl#type#dispatch', [a:Func] + a:args)
  else
    return call('timl#type#dispatch', [g:timl#core#_invoke, a:Func] + (a:0 ? [a:1] : []) + a:args)
  endif
endfunction

function! s:lencompare(a, b)
  return len(a:b) - len(a:b)
endfunction

function! timl#ns_for_file(file) abort
  let file = fnamemodify(a:file, ':p')
  let candidates = []
  for glob in split(&runtimepath, ',')
    let candidates += filter(split(glob(glob), "\n"), 'file[0 : len(v:val)-1] ==# v:val && file[len(v:val)] =~# "[\\/]"')
  endfor
  if empty(candidates)
    return 'user'
  endif
  let dir = sort(candidates, s:function('s:lencompare'))[-1]
  let path = file[len(dir)+1 : -1]
  return substitute(tr(fnamemodify(path, ':r:r'), '\/_', '..-'), '^\%(autoload\|plugin\|test\).', '', '')
endfunction

function! timl#ns_for_cursor(...) abort
  call timl#loader#init()
  let pattern = '\c(\%(in-\)\=ns\s\+''\=[[:alpha:]]\@='
  let line = 0
  if !a:0 || a:1
    let line = search(pattern, 'bcnW')
  endif
  if !line
    let i = 1
    while i < line('$') && i < 100
      if getline(i) =~# pattern
        let line = i
        break
      endif
      let i += 1
    endwhile
  endif
  if line
    let ns = matchstr(getline(line), pattern.'\zs[[:alnum:]._-]\+')
  else
    let ns = timl#ns_for_file(expand('%:p'))
  endif
  if !exists('g:autoloaded_timl_compiler')
    runtime! autoload/timl/compiler.vim
  endif
  let nsobj = timl#namespace#find(timl#symbol(ns))
  if nsobj isnot# g:timl#nil
    return ns
  else
    return 'user'
  endif
endfunction

function! timl#eval(x) abort
  return timl#loader#eval(a:x)
endfunction

function! timl#re(str) abort
  return timl#eval(timl#reader#read_string(a:str))
endfunction

function! timl#rep(str) abort
  return timl#printer#string(timl#re(a:str))
endfunction

runtime! autoload/timl/bootstrap.vim

" }}}1

" vim:set et sw=2:
