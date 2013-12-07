if exists("g:autoloaded_timl_vim")
  finish
endif
let g:autoloaded_timl_vim = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

" Section: Number

let g:timl#vim#Number = {}

" Section: String

" Characters, not bytes
function! s:str_get(this, idx, ...) abort
  if type(a:idx) == type(0)
    let ch = matchstr(a:this, repeat('.', a:idx).'\zs.')
    return empty(ch) ? (a:0 ? a:1 : g:timl#nil) : ch
  endif
  return a:0 ? a:1 : g:timl#nil
endfunction

let g:timl#vim#String = {
      \ "implements":
      \ {"timl.lang/ILookup":
      \    {"get": s:function("s:str_get")}}}

" Section: Funcref

function! s:funcall(this, args)
  return call(a:this, a:args, {'__fn__': a:this})
endfunction

let g:timl#vim#Funcref = {
      \ "implements":
      \ {"timl.lang/IFn":
      \   {"invoke": s:function('s:funcall')}}}

" Section: List

function! s:list_get(this, idx, ...) abort
  if type(a:idx) == type(0)
    return get(a:this, a:idx, a:0 ? a:1 : g:timl#nil)
  endif
  return a:0 ? a:1 : g:timl#nil
endfunction

let g:timl#vim#List = {
      \ "implements":
      \ {"timl.lang/Seqable":
      \    {"seq": function("timl#list2")},
      \  "timl.lang/ILookup":
      \    {"get": s:function("s:list_get")},
      \  "timl.lang/IFn":
      \    {"invoke": s:function("s:list_get")}}}

" Section: Dictionary

function! s:dict_seq(dict) abort
  return timl#list2(items(a:dict))
endfunction

function! s:dict_get(this, key, ...) abort
  return get(a:this, timl#str(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

let g:timl#vim#Dictionary = {
      \ "implements":
      \ {"timl.lang/Seqable":
      \    {"seq": s:function("s:dict_seq")},
      \  "timl.lang/ILookup":
      \    {"get": s:function("s:dict_get")},
      \  "timl.lang/IFn":
      \    {"invoke": s:function("s:dict_get")}}}

" Section: Float

if has('float')
  let g:timl#vim#Float = {}
endif

" vim:set et sw=2:
