if exists("g:autoloaded_timl_vim")
  finish
endif
let g:autoloaded_timl_vim = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

" Section: Number

let g:timl#vim#Number = timl#bless('timl.lang/Type', {"name": timl#symbol('timl.vim/Number')})

" Section: String

" Characters, not bytes
function! s:str_lookup(this, idx, default) abort
  if type(a:idx) == type(0)
    let ch = matchstr(a:this, repeat('.', a:idx).'\zs.')
    return empty(ch) ? (a:0 ? a:1 : g:timl#nil) : ch
  endif
  return a:default
endfunction

function! s:string_count(this) abort
  return exists('*strchars') ? strchars(a:this) : len(substitute(a:this, '.', '.', 'g'))
endfunction

let g:timl#vim#String = timl#bless('timl.lang/Type', {
      \ "name": timl#symbol('timl.vim/String'),
      \ "implements":
      \ {"timl.lang/ILookup":
      \    {"lookup": s:function("s:str_lookup")},
      \  "timl.lang/ICounted":
      \    {"count": s:function("s:string_count")}}})

" Section: Funcref

function! s:funcall(this, args)
  return call(a:this, a:args, {'__fn__': a:this})
endfunction

let g:timl#vim#Funcref = timl#bless('timl.lang/Type', {
      \ "name": timl#symbol('timl.vim/Funcref'),
      \ "implements":
      \ {"timl.lang/IFn":
      \   {"invoke": s:function('s:funcall')}}})

" Section: List

function! s:list_seq(this) abort
  return empty(a:this) ? g:timl#nil : g:timl#lang#ChunkedCons.create(a:this)
endfunction

function! s:list_first(this) abort
  return get(a:this, 0, g:timl#nil)
endfunction

function! s:list_rest(this) abort
  return len(a:this) <= 1 ? g:timl#empty_list : g:timl#lang#ChunkedCons.create(a:this, g:timl#empty_list, 1)
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

let g:timl#vim#List = timl#bless('timl.lang/Type', {
      \ "name": timl#symbol('timl.vim/List'),
      \ "implements":
      \ {"timl.lang/ISeqable":
      \    {"seq": s:function("s:list_seq")},
      \  "timl.lang/ISeq":
      \    {"first": s:function("s:list_first"),
      \     "rest": s:function("s:list_rest")},
      \  "timl.lang/ILookup":
      \    {"lookup": s:function("s:list_lookup")},
      \  "timl.lang/ICounted":
      \    {"count": function("len")},
      \  "timl.lang/ICollection":
      \    {"cons": s:function("s:list_cons"),
      \     "empty": s:function("s:list_empty")},
      \  "timl.lang/IFn":
      \    {"invoke": s:function("s:list_lookup")}}})

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

let g:timl#vim#Dictionary = timl#bless('timl.lang/Type', {
      \ "name": timl#symbol('timl.vim/Dictionary'),
      \ "implements":
      \ {"timl.lang/ISeqable":
      \    {"seq": s:function("s:dict_seq")},
      \  "timl.lang/ILookup":
      \    {"get": s:function("s:dict_lookup")},
      \  "timl.lang/ICounted":
      \    {"count": function("len")},
      \  "timl.lang/ICollection":
      \    {"cons": s:function("s:dict_cons"),
      \     "empty": s:function("s:dict_empty")},
      \  "timl.lang/IFn":
      \    {"invoke": s:function("s:dict_lookup")}}})

" Section: Float

if has('float')
  let g:timl#vim#Float = timl#bless('timl.lang/Type', {"name": timl#symbol('timl.vim/Float')})
endif

" vim:set et sw=2:
