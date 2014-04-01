" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_atom")
  finish
endif
let g:autoloaded_timl_atom = 1

function! timl#atom#create(state, meta, validator) abort
  if a:validator is# g:timl#nil || timl#truth(timl#invoke(a:validator, a:state))
    return s:type.__call__([a:state, a:meta, a:validator, g:timl#nil])
  endif
  throw 'timl: invalid state'
endfunction

function! timl#atom#deref(this) abort
  return a:this.state
endfunction

function! timl#atom#reset(this, state) abort
  if a:this.validator is# g:timl#nil || timl#truth(timl#invoke(a:this.validator, a:state))
    let a:this.state = a:state
    return a:state
  endif
  throw 'timl: invalid state'
endfunction

function! timl#atom#swap(this, fn, ...) abort
  return timl#atom#reset(a:this, timl#call(a:fn, [a:this.state] + a:000))
endfunction

function! timl#atom#compare_and_set(this, old, new) abort
  if a:this.state is# a:this.old
  return timl#atom#reset(a:this, a:new)
endfunction

function! timl#atom#reset_meta(this, meta) abort
  let a:this.meta = a:meta
  return a:this
endfunction

function! timl#atom#set_validator(this, validator) abort
  if a:validator is g:timl#nil || timl#truth(timl#invoke(a:validator, a:this.state))
    let a:this.validator = a:validator
    return a:this
  endif
  throw 'timl: invalid state'
endfunction

function! timl#atom#get_validator(this) abort
  return a:this.validator
endfunction

let s:type = timl#type#core_define('Atom', ['state', 'meta', 'validator', 'watches'], {
      \ 'get-meta': 'timl#meta#from_attribute',
      \ 'reset!': 'timl#atom#reset',
      \ 'swap!': 'timl#atom#swap',
      \ 'compare-and-set!': 'timl#atom#compare_and_set',
      \ 'reset-meta!': 'timl#atom#reset_meta',
      \ 'set-validator!': 'timl#atom#set_validator',
      \ 'get-validator': 'timl#atom#get_validator',
      \ 'deref': 'timl#atom#deref'})
