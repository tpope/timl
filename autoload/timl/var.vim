" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_var')
  finish
endif
let g:autoloaded_timl_var = 1

function! timl#var#get(var) abort
  return eval(a:var.location)
endfunction

function! timl#var#call(var, _) abort
  return timl#call(eval(a:var.location), a:_)
endfunction

function! timl#var#test(this) abort
  return timl#type#string(a:this) ==# 'timl.lang/Var'
endfunction

function! timl#var#find(sym) abort
  let sym = timl#symbol#cast(a:sym)
  let ns = empty(sym.namespace) ? timl#namespace#name(g:timl#core._STAR_ns_STAR_).str : sym.namespace
  return get(timl#namespace#find(ns).__mappings__, sym.name, g:timl#nil)
endfunction

function! timl#var#funcref(var) abort
  return function(a:var.munged)
endfunction

function! timl#var#reset_meta(var, meta) abort
  let a:var.meta = a:meta
  return a:var
endfunction

" Section: Munging

" From clojure/lang/Compiler.java
let s:munge = {
      \ '.': "#",
      \ ',': "_COMMA_",
      \ ':': "_COLON_",
      \ '+': "_PLUS_",
      \ '>': "_GT_",
      \ '<': "_LT_",
      \ '=': "_EQ_",
      \ '~': "_TILDE_",
      \ '!': "_BANG_",
      \ '@': "_CIRCA_",
      \ "'": "_SINGLEQUOTE_",
      \ '"': "_DOUBLEQUOTE_",
      \ '%': "_PERCENT_",
      \ '^': "_CARET_",
      \ '&': "_AMPERSAND_",
      \ '*': "_STAR_",
      \ '|': "_BAR_",
      \ '{': "_LBRACE_",
      \ '}': "_RBRACE_",
      \ '[': "_LBRACK_",
      \ ']': "_RBRACK_",
      \ '/': "_SLASH_",
      \ '\\': "_BSLASH_",
      \ '?': "_QMARK_"}

let s:demunge = {}
for s:key in keys(s:munge)
  let s:demunge[s:munge[s:key]] = s:key
endfor
unlet! s:key

function! timl#var#munge(var) abort
  let var = type(a:var) == type('') ? a:var : a:var[0]
  return tr(substitute(substitute(var, '[^[:alnum:]:#_-]', '\=get(s:munge,submatch(0), submatch(0))', 'g'), '_SLASH_\ze.', '.', ''), '-', '_')
endfunction

function! timl#var#demunge(var) abort
  let var = type(a:var) == type('') ? a:var : a:var[0]
  return tr(substitute(var, '_\(\u\+\)_', '\=get(s:demunge, submatch(0), submatch(0))', 'g'), '_', '-')
endfunction
