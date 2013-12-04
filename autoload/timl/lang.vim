" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lang")
  finish
endif
let g:autoloaded_timl_lang = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

" Nil {{{1

function! s:identity(x)
  return a:x
endfunction

function! s:nil_get(this, key, ...)
  return a:0 ? a:1 : g:timl#nil
endfunction

let g:timl#lang#Nil = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": s:function("s:identity")},
      \  "timl#lang#ISeq":
      \    {"first": s:function('s:identity'),
      \     "rest": s:function('s:identity')},
      \ "timl#lang#ILookup":
      \    {"get": s:function('s:nil_get')}}}

" }}}1
" Cons {{{1

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
      \  "timl#lang#ISeq":
      \    {"first": s:function('s:cons_car'),
      \     "rest": s:function('s:cons_cdr')}}}

" }}}1
" Hashes {{{1

function! s:map_seq(hash)
  return timl#list2(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), '[timl#dekey(v:val[0]), v:val[1]]'))
endfunction

function! s:map_get(this, key, ...)
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

let g:timl#lang#HashMap = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": s:function('s:map_seq')},
      \  "timl#lang#ILookup":
      \    {"get": s:function('s:map_get')}}}

function! s:set_seq(hash)
  return timl#list2(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), 'v:val[1]'))
endfunction

function! s:set_get(this, key, ...)
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

let g:timl#lang#HashSet = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": s:function("s:set_seq")},
      \  "timl#lang#ILookup":
      \    {"get": s:function('s:set_get')}}}

" }}}1
