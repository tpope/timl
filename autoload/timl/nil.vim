" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_nil")
  finish
endif
let g:autoloaded_timl_nil = 1

function! s:freeze(...) abort
  return a:000
endfunction

if !exists('g:timl#nil')
  let g:timl#nil = s:freeze()
  lockvar 1 g:timl#nil
endif

function! timl#nil#identity(...) abort
  return g:timl#nil
endfunction

function! timl#nil#length(...) abort
  return 0
endfunction

function! timl#nil#to_string(...) abort
  return ''
endfunction

function! timl#nil#test(this) abort
  return a:this is# g:timl#nil
endfunction

function! timl#nil#lookup(this, key, default) abort
  return a:default
endfunction

function! timl#nil#cons(this, ...) abort
  return call('timl#cons#conj', [timl#list#empty()] + a:000)
endfunction

function! timl#nil#assoc(this, ...) abort
  return timl#map#create(a:000)
endfunction

call timl#type#core_define('Nil', g:timl#nil, {
      \ 'seq': 'timl#nil#identity',
      \ 'to-string': 'timl#nil#to_string',
      \ 'empty': 'timl#nil#identity',
      \ 'car': 'timl#nil#identity',
      \ 'cdr': 'timl#list#empty',
      \ 'conj': 'timl#nil#cons',
      \ 'assoc': 'timl#nil#assoc',
      \ 'length': 'timl#nil#length',
      \ 'hash': 'timl#nil#length',
      \ 'lookup': 'timl#nil#lookup'})
