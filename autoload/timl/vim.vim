if exists("g:autoloaded_timl_vim")
  finish
endif
let g:autoloaded_timl_vim = 1

let g:timl#vim#Number = {}

let g:timl#vim#String = {}

let g:timl#vim#Funcref = {}

let g:timl#vim#List = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": function("timl#persistent")}}}

let g:timl#vim#Dictionary = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": function("items")}}}

if has('float')
  let g:timl#vim#Float = {}
endif
