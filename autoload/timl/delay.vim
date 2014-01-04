" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_delay")
  finish
endif
let g:autoloaded_timl_delay = 1

function! timl#delay#create(fn) abort
  return s:type.__call__([a:fn, g:timl#nil])
endfunction

function! timl#delay#force(this) abort
  if timl#type#string(a:this) !=# s:type.str
    return a:this
  endif
  return timl#delay#deref(a:this)
endfunction

function! timl#delay#deref(this) abort
  if a:this.fn is# g:timl#nil
    return a:this.val
  endif
  let a:this.val = timl#call(a:this.fn, [])
  let a:this.fn = g:timl#nil
  return a:this.val
endfunction

function! timl#delay#realized(this) abort
  return a:this.fn is# g:timl#nil ? g:timl#true : g:timl#false
endfunction

let s:type = timl#type#core_define('Delay', ['fn', 'val'], {
      \ 'realized?': 'timl#delay#realized',
      \ 'deref': 'timl#delay#deref'})
