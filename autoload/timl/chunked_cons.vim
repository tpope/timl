" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_chunked_cons")
  finish
endif
let g:autoloaded_timl_chunked_cons = 1

let s:type = timl#type#intern('timl.lang/ChunkedCons')
function! timl#chunked_cons#create(array, rest, ...) abort
  lockvar 1 a:array
  let cc = timl#bless(s:type, {
        \ 'array': a:array,
        \ 'rest': a:rest,
        \ 'meta': g:timl#nil,
        \ 'i': a:0 ? a:1 : 0})
  lockvar 1 cc
  return cc
endfunction

function! timl#chunked_cons#first(this) abort
  return get(a:this.array, a:this.i, g:timl#nil)
endfunction

function! timl#chunked_cons#more(this) abort
  if len(a:this.array) - a:this.i <= 1
    return a:this.rest
  else
    return timl#chunked_cons#create(a:this.array, a:this.rest, a:this.i+1)
  endif
endfunction

function! timl#chunked_cons#length(this) abort
  let c = len(a:this.array) - a:this.i
  let _ = {'next': timl#seq(a:this.rest)}
  while timl#type#string(_.next) ==# 'timl.lang/ChunkedCons'
    let c += len(_.next.array) - _.next.i
    let _.next = timl#seq(timl#chunked_cons#chunk_rest(_.next))
  endwhile
  return c + timl#coll#count(_.next)
endfunction

function! timl#chunked_cons#chunk_first(this) abort
  return a:this.array[a:this.i : -1]
endfunction

function! timl#chunked_cons#chunk_rest(this) abort
  return a:this.rest
endfunction
