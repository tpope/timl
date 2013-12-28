" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_list")
  finish
endif
let g:autoloaded_timl_list = 1

let s:empty_type = timl#type#intern('timl.lang/EmptyList')
if !exists('s:empty')
  let s:empty = timl#bless(s:empty_type, {'meta': g:timl#nil})
  lockvar 1 s:empty
endif

function! timl#list#empty() abort
  return s:empty
endfunction

function! timl#list#emptyp(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '__tag__') is# s:empty_type
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
