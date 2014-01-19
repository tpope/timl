" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_var')
  finish
endif
let g:autoloaded_timl_var = 1

function! timl#var#get(var) abort
  return g:{a:var.munged}
endfunction

function! timl#var#call(var, _) abort
  return timl#call(g:{a:var.munged}, a:_)
endfunction

function! timl#var#test(this) abort
  return timl#type#string(a:this) ==# 'timl.lang/Var'
endfunction

function! timl#var#find(sym) abort
  let sym = timl#symbol#cast(a:sym)
  let ns = empty(sym.namespace) ? timl#namespace#name(g:timl#core#_STAR_ns_STAR_).str : sym.namespace
  return get(timl#namespace#find(ns).mappings, sym.name, g:timl#nil)
endfunction

function! timl#var#funcref(var) abort
  return function(a:var.munged)
endfunction

function! timl#var#reset_meta(var, meta) abort
  let a:var.meta = a:meta
  return a:var
endfunction
