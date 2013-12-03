" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lang")
  finish
endif
let g:autoloaded_timl_lang = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

function! timl#lang#hash_map_seq(hash)
  return timl#list2(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), '[timl#dekey(v:val[0]), v:val[1]]'))
endfunction

function! timl#lang#hash_set_seq(hash)
  return timl#list2(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), 'v:val[1]'))
endfunction

function! s:identity(x)
  return a:x
endfunction

function! s:cons_car(cons)
  return a:cons.car
endfunction

function! s:cons_cdr(cons)
  return a:cons.cdr
endfunction

let g:timl#lang#Cons = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": s:function("s:identity")},
      \  "timl#lang#Seq":
      \    {"first": s:function('s:cons_car'),
      \     "rest": s:function('s:cons_cdr')}}}

let g:timl#lang#HashMap = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": function("timl#lang#hash_map_seq")}}}

let g:timl#lang#HashSet = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": function("timl#lang#hash_set_seq")}}}
