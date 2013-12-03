" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lang")
  finish
endif
let g:autoloaded_timl_lang = 1

function! timl#lang#hash_map_seq(hash)
  return timl#persistent(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), '[timl#dekey(v:val[0]), v:val[1]]'))
endfunction

function! timl#lang#hash_set_seq(hash)
  return timl#persistent(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), 'v:val[1]'))
endfunction

let g:timl#lang#Cons = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": function("timl#vec")}}}

let g:timl#lang#HashMap = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": function("timl#lang#hash_map_seq")}}}

let g:timl#lang#HashSet = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": function("timl#lang#hash_set_seq")}}}
