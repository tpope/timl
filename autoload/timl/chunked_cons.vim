" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_chunked_cons")
  finish
endif
let g:autoloaded_timl_chunked_cons = 1

function! timl#chunked_cons#create(array, rest, ...) abort
  lockvar 1 a:array
  let cc = timl#type#bless(s:type, {
        \ 'array': a:array,
        \ 'rest': a:rest,
        \ 'meta': g:timl#nil,
        \ 'i': a:0 ? a:1 : 0})
  lockvar 1 cc
  return cc
endfunction

function! timl#chunked_cons#car(this) abort
  return get(a:this.array, a:this.i, g:timl#nil)
endfunction

function! timl#chunked_cons#cdr(this) abort
  if len(a:this.array) - a:this.i <= 1
    return a:this.rest
  else
    return timl#chunked_cons#create(a:this.array, a:this.rest, a:this.i+1)
  endif
endfunction

function! timl#chunked_cons#length(this) abort
  let c = len(a:this.array) - a:this.i
  let _ = {'next': timl#coll#seq(a:this.rest)}
  while timl#type#string(_.next) ==# s:type.str
    let c += len(_.next.array) - _.next.i
    let _.next = timl#coll#seq(timl#chunked_cons#chunk_rest(_.next))
  endwhile
  return c + timl#coll#count(_.next)
endfunction

function! timl#chunked_cons#chunk_first(this) abort
  return a:this.array[a:this.i : -1]
endfunction

function! timl#chunked_cons#chunk_rest(this) abort
  return a:this.rest
endfunction

let s:type = timl#type#core_define('ChunkedCons', ['array', 'rest', 'i', 'meta'], {
      \ 'get-meta': 'timl#meta#from_attribute',
      \ 'with-meta': 'timl#meta#copy_assign_lock',
      \ 'seq': 'timl#function#identity',
      \ 'equiv': 'timl#equality#seq',
      \ 'car': 'timl#chunked_cons#car',
      \ 'cdr': 'timl#chunked_cons#cdr',
      \ 'length': 'timl#chunked_cons#length',
      \ 'conj': 'timl#cons#conj',
      \ 'empty': 'timl#list#empty',
      \ 'chunk-first': 'timl#chunked_cons#chunk_first',
      \ 'chunk-rest': 'timl#chunked_cons#chunk_rest'})
