" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_funcref")
  finish
endif
let g:autoloaded_timl_funcref = 1

function! timl#funcref#call(this, _) abort
  return call(a:this, a:_)
endfunction

let s:type = type(function('tr'))
function! timl#funcref#test(this) abort
  return type(a:this) == s:type
endfunction

function! timl#funcref#string(this) abort
  return join([a:this])
endfunction

function! timl#funcref#hash(this) abort
  return timl#hash#string(string(a:this))
endfunction

function! timl#funcref#exists(name) abort
  return exists(a:name =~# '^\d\+$' ? '*{'.a:name.'}' : '*'.a:name)
endfunction

function! timl#funcref#anonymous() abort
  let d = {}
  function! d.f() abort
    return +matchstr(expand('<sfile>'), '\d\+$')
  endfunction
  return d.f
endfunction
