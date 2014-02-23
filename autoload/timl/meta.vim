" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_meta')
  finish
endif
let g:autoloaded_timl_meta = 1

function! timl#meta#get(obj) abort
  if !timl#type#canp(a:obj, g:timl#core.get_meta)
    return g:timl#nil
  endif
  return timl#invoke(g:timl#core.get_meta, a:obj)
endfunction

function! timl#meta#with(obj, meta) abort
  return timl#invoke(g:timl#core.with_meta, a:obj, a:meta)
endfunction

function! timl#meta#vary(obj, fn, ...) abort
  return timl#meta#with(a:obj, timl#call(a:fn, [timl#meta#get(a:obj)] + a:000))
endfunction

function! timl#meta#alter(obj, fn, ...) abort
  return timl#call(g:timl#core.reset_meta_BANG_, [a:obj, timl#call(a:fn, [timl#meta#get(a:obj)] + a:000)])
endfunction

function! timl#meta#from_attribute(obj) abort
  return get(a:obj, 'meta', g:timl#nil)
endfunction

function! timl#meta#copy_assign_lock(obj, meta) abort
  if a:obj.meta isnot# a:meta
    let obj = copy(a:obj)
    let obj.meta = a:meta
    lockvar 1 obj
    return obj
  endif
  return a:obj
endfunction

function! timl#meta#copy_assign(obj, meta) abort
  if a:obj.meta isnot# a:meta
    let obj = copy(a:obj)
    let obj.meta = a:meta
    return obj
  endif
  return a:obj
endfunction
