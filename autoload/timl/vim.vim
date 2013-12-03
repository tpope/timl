if exists("g:autoloaded_timl_vim")
  finish
endif
let g:autoloaded_timl_vim = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

let g:timl#vim#Number = {}

let g:timl#vim#String = {}

let g:timl#vim#Funcref = {}

let g:timl#vim#List = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": function("timl#list2")}}}

function! s:dict_seq(dict)
  return timl#list2(items(a:dict))
endfunction

let g:timl#vim#Dictionary = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": s:function("s:dict_seq")}}}

if has('float')
  let g:timl#vim#Float = {}
endif
