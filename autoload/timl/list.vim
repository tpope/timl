" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_list")
  finish
endif
let g:autoloaded_timl_list = 1

let s:cons_type = timl#type#intern('timl.lang/Cons')

function! timl#list#create(array, ...) abort
  if a:0 && empty(a:array)
    return timl#type#bless(s:empty_type, {'meta': a:1})
  endif
  let _ = {'cdr': s:empty}
  for i in range(len(a:array)-1, 0, -1)
    let _.cdr = timl#cons#create(a:array[i], _.cdr)
  endfor
  if a:0
    let _.cdr.meta = a:1
  endif
  return _.cdr
endfunction

function! timl#list#with_meta(this, meta) abort
  if timl#equalp(a:this.meta, a:meta)
    return a:this
  endif
  let this = copy(a:this)
  let this.meta = a:meta
  lockvar 1 this
  return this
endfunction

function! timl#list#empty() abort
  return s:empty
endfunction

let s:empty_type = timl#type#intern('timl.lang/EmptyList')
if !exists('s:empty')
  let s:empty = timl#type#bless(s:empty_type, {'meta': g:timl#nil})
  lockvar 1 s:empty
endif

function! timl#list#emptyp(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '__tag__') is# s:empty_type
endfunction

function! timl#list#test(obj)
  return type(a:obj) == type({}) && (get(a:obj, '__tag__') is# s:cons_type || get(a:obj, '__tag__') is# s:empty_type)
endfunction
