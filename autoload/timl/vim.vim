if exists("g:autoloaded_timl_vim")
  finish
endif
let g:autoloaded_timl_vim = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

function! s:implement(type, ...)
  let type = timl#keyword(a:type)
  for i in range(0, a:0-1, 2)
    call timl#type#define_method('timl.core', a:000[i], type, a:000[i+1])
  endfor
endfunction

" Section: Number

" Section: String

" Characters, not bytes
function! s:string_lookup(this, idx, default) abort
  if type(a:idx) == type(0)
    let ch = matchstr(a:this, repeat('.', a:idx).'\zs.')
    return empty(ch) ? (a:0 ? a:1 : g:timl#nil) : ch
  endif
  return a:default
endfunction

function! s:string_count(this) abort
  return exists('*strchars') ? strchars(a:this) : len(substitute(a:this, '.', '.', 'g'))
endfunction

call s:implement('vim/String',
      \ 'lookup', s:function('s:string_lookup'),
      \ 'count', s:function('s:string_count'))

" Section: Funcref

function! s:funcall(this, args)
  return call(a:this, a:args, {'__fn__': a:this})
endfunction

call s:implement('vim/Funcref', '_invoke', s:function('s:funcall'))

" Section: List

function! s:list_seq(this) abort
  return empty(a:this) ? g:timl#nil : timl#lang#create_chunked_cons(a:this)
endfunction

function! s:list_first(this) abort
  return get(a:this, 0, g:timl#nil)
endfunction

function! s:list_rest(this) abort
  return len(a:this) <= 1 ? g:timl#empty_list : timl#lang#create_chunked_cons(a:this, g:timl#empty_list, 1)
endfunction

function! s:list_lookup(this, idx, ...) abort
  if type(a:idx) == type(0)
    return get(a:this, a:idx, a:0 ? a:1 g:timl#nil)
  endif
  return a:0 ? a:1 : g:timl#nil
endfunction

function! s:list_nth(this, idx, ...) abort
  let idx = timl#int(a:idx)
  if a:0
    return get(a:this, idx, a:1)
  else
    return a:this[idx]
  endif
endfunction

function! s:list_cons(this, ...) abort
  return timl#persistentb(a:this + a:000)
endfunction

function! s:list_empty(this) abort
  let this = a:this
  let empty = []
  if islocked('this')
    lockvar 1 empty
  endif
  return this
endfunction

call s:implement('vim/List',
      \ 'seq', s:function('s:list_seq'),
      \ 'first', s:function("s:list_first"),
      \ 'more', s:function("s:list_rest"),
      \ 'lookup', s:function('s:list_lookup'),
      \ 'nth', s:function('s:list_nth'),
      \ 'count', s:function('len'),
      \ 'conj', s:function('s:list_cons'),
      \ 'empty', s:function('s:list_empty'),
      \ '_invoke', s:function('s:list_lookup'))

" Section: Dictionary

function! s:dict_seq(dict) abort
  return timl#list2(items(a:dict))
endfunction

function! s:dict_lookup(this, key, ...) abort
  return get(a:this, timl#str(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

function! s:dict_cons(this, ...) abort
  let this = copy(a:this)
  let _ = {}
  for _.e in a:000
    let this[timl#str(timl#first(_.e))] = timl#fnext(_.e)
  endfor
  return this
endfunction

function! s:dict_assoc(this, ...) abort
  let this = copy(a:this)
  let _ = {}
  for i in range(0, len(a:000)-2, 2)
    let this[timl#str(a:000[i])] = a:000[i+1]
  endfor
  lockvar 1 this
  return this
endfunction

function! s:dict_dissoc(this, ...) abort
  let _ = {}
  let this = copy(a:this)
  for _.x in a:000
    let key = timl#str(_.x)
    if has_key(this, key)
      call remove(this, key)
    endif
  endfor
  return this
endfunction

function! s:dict_empty(this) abort
  let this = a:this
  let empty = {}
  if islocked('this')
    lockvar 1 empty
  endif
  return this
endfunction

call s:implement('vim/Dictionary',
      \ 'seq', s:function('s:dict_seq'),
      \ 'lookup', s:function('s:dict_lookup'),
      \ 'count', s:function('len'),
      \ 'empty', s:function('s:dict_empty'),
      \ 'conj', s:function('s:dict_cons'),
      \ 'assoc', s:function('s:dict_assoc'),
      \ 'dissoc', s:function('s:dict_dissoc'),
      \ '_invoke', s:function('s:dict_lookup'))

" Section: Float

" vim:set et sw=2:
