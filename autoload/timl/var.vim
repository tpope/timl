" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_var')
  finish
endif
let g:autoloaded_timl_var = 1

function! timl#var#get(var) abort
  return g:{a:var.munged}
endfunction

function! timl#var#invoke(var, ...) abort
  return timl#call(g:{a:var.munged}, a:000)
endfunction

function! timl#var#test(this) abort
  return timl#type#string(a:this) ==# 'timl.lang/Var'
endfunction

function! timl#var#find(ns_str, name_str) abort
  return timl#namespace#find(a:ns_str).mappings[a:name_str]
endfunction
