" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_list")
  finish
endif
let g:autoloaded_timl_list = 1

let s:cons_type = timl#type#core_create('Cons', ['car', 'cdr', 'meta'])

function! timl#list#create(array, ...) abort
  if a:0 && empty(a:array)
    return timl#type#bless(s:empty_type, {'meta': a:1})
  endif
  let _ = {'cdr': s:empty}
  for i in range(len(a:array)-1, 0, -1)
    let _.cdr = timl#cons#create(a:array[i], _.cdr)
  endfor
  if a:0
    let _.cdr.meta = a:1
  endif
  return _.cdr
endfunction

function! timl#list#with_meta(this, meta) abort
  if a:this.meta is# a:meta
    return a:this
  endif
  let this = copy(a:this)
  let this.meta = a:meta
  lockvar 1 this
  return this
endfunction

function! timl#list#empty() abort
  return s:empty
endfunction

function! timl#list#emptyp(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '__type__') is# s:empty_type
endfunction

function! timl#list#test(obj) abort
  return type(a:obj) == type({}) && (get(a:obj, '__type__') is# s:cons_type || get(a:obj, '__type__') is# s:empty_type)
endfunction

let s:empty_type = timl#type#core_define('EmptyList', ['meta'], {
      \ 'get-meta': 'timl#meta#from_attribute',
      \ 'with-meta': 'timl#list#with_meta',
      \ 'seq': 'timl#nil#identity',
      \ 'equiv': 'timl#equality#seq',
      \ 'car': 'timl#nil#identity',
      \ 'cdr': 'timl#function#identity',
      \ 'length': 'timl#nil#length',
      \ 'conj': 'timl#cons#conj',
      \ 'empty': 'timl#function#identity'})

if !exists('s:empty')
  let s:empty = timl#type#bless(s:empty_type, {'meta': g:timl#nil})
  lockvar 1 s:empty
endif
