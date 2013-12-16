" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_meta')
  finish
endif
let g:autoloaded_timl_meta = 1

function! timl#meta#vary(obj, fn, ...) abort
  return timl#with_meta(a:obj, timl#call(a:fn, [timl#meta(a:obj)] + a:000))
endfunction

function! timl#meta#alter(obj, fn, ...) abort
  return timl#call(g:timl#core#reset_meta_BANG_, [a:obj, timl#call(a:fn, [timl#meta(a:obj)] + a:000)])
endfunction

function! timl#meta#from_attribute(obj) abort
  return get(a:obj, 'meta', g:timl#nil)
endfunction

function! timl#meta#copy_assign_lock(obj, meta) abort
  if !timl#equalp(get(a:obj, 'meta', g:timl#nil), a:meta)
    let obj = copy(a:obj)
    if a:meta is# g:timl#nil
      call remove(obj, 'meta')
    else
      let obj.meta = a:meta
    endif
    lockvar 1 obj
    return obj
  endif
  return a:obj
endfunction

function! timl#meta#copy_assign(obj, meta) abort
  if !timl#equalp(get(a:obj, 'meta', g:timl#nil), a:meta)
    let obj = copy(a:obj)
    if a:meta is# g:timl#nil
      call remove(obj, 'meta')
    else
      let obj.meta = a:meta
    endif
    return obj
  endif
  return a:obj
endfunction
