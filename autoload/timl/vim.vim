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

call s:implement('timl.vim/String',
      \ '_lookup', s:function('s:string_lookup'),
      \ '_count', s:function('s:string_count'))

" Section: Funcref

function! s:funcall(this, args)
  return call(a:this, a:args, {'__fn__': a:this})
endfunction

call s:implement('timl.vim/Funcref', '_invoke', s:function('s:funcall'))

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

function! s:list_cons(this, other) abort
  return timl#persistentb(a:this + [a:other])
endfunction

let s:empty_list = timl#persistentb([])
function! s:list_empty(this) abort
  return s:empty_list
endfunction

call s:implement('timl.vim/List',
      \ 'seq', s:function('s:list_seq'),
      \ 'first', s:function("s:list_first"),
      \ 'rest', s:function("s:list_rest"),
      \ '_lookup', s:function('s:list_lookup'),
      \ '_count', s:function('len'),
      \ '_conj', s:function('s:list_cons'),
      \ 'empty', s:function('s:list_empty'),
      \ '_invoke', s:function('s:list_lookup'))

" Section: Dictionary

function! s:dict_seq(dict) abort
  return timl#list2(items(a:dict))
endfunction

function! s:dict_lookup(this, key, ...) abort
  return get(a:this, timl#str(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

function! s:dict_cons(this, x) abort
  return timl#persistentb(extend(timl#transient(a:this), {timl#str(timl#first(a:x)): timl#first(timl#rest(a:x))}))
endfunction

let s:empty_dict = timl#persistentb({})
function! s:dict_empty(this) abort
  return s:empty_dict
endfunction

call s:implement('timl.vim/Dictionary',
      \ 'seq', s:function('s:dict_seq'),
      \ '_lookup', s:function('s:dict_lookup'),
      \ '_count', s:function('len'),
      \ '_conj', s:function('s:dict_cons'),
      \ 'empty', s:function('s:dict_empty'),
      \ '_invoke', s:function('s:dict_lookup'))

" Section: Float

" vim:set et sw=2:
