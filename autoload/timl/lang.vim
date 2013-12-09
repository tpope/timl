" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lang")
  finish
endif
let g:autoloaded_timl_lang = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

let s:type = timl#intern_type('timl.lang/Type')
let g:timl#lang#Type = timl#bless(s:type, {'name': timl#symbol('timl.lang/Type')})

function! s:identity(x)
  return a:x
endfunction

function! s:nil(...)
  return g:timl#nil
endfunction

function! s:empty_list(...)
  return g:timl#empty_list
endfunction

function! s:zero(...)
  return 0
endfunction

" Section: Nil

function! s:nil_get(this, key, ...)
  return a:0 ? a:1 : g:timl#nil
endfunction

let g:timl#lang#Nil = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/Nil'),
      \ "implements":
      \ {"timl.lang/Seqable":
      \    {"seq": s:function("s:nil")},
      \  "timl.lang/ISeq":
      \    {"first": s:function('s:nil'),
      \     "rest": s:function('s:empty_list')},
      \ "timl.lang/ILookup":
      \    {"get": s:function('s:nil_get')}}})

" Section: Boolean

let g:timl#lang#Boolean = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/Nil')})

" Section: Symbols/Keywords

function! s:this_get(this, coll, ...) abort
  if a:0
    return timl#dispatch('timl.lang/ILookup', 'get', a:coll, a:this, a:1)
  else
    return timl#dispatch('timl.lang/ILookup', 'get', a:coll, a:this)
  endif
endfunction

let g:timl#lang#Symbol = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/Symbol'),
      \ "implements":
      \ {"timl.lang/IFn":
      \    {"invoke": s:function('s:this_get')}}})

let g:timl#lang#Keyword = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/Keyword'),
      \ "implements":
      \ {"timl.lang/IFn":
      \    {"invoke": s:function('s:this_get')}}})

" Section: Function

function! s:function_invoke(this, ...) abort
  return call(a:this.call, a:000, a:this)
endfunction

let g:timl#lang#Function = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/Function'),
      \ "implements":
      \ {"timl.lang/IFn":
      \    {"invoke": s:function('s:function_invoke')}}})

" Section: Cons

function! s:cons_car(cons)
  return a:cons.car
endfunction

function! s:cons_cdr(cons)
  return timl#seq(a:cons.cdr)
endfunction

function! s:cons_cons(cdr, car)
  return timl#cons(a:car, a:cdr)
endfunction

let g:timl#lang#Cons = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/Cons'),
      \ "implements":
      \ {"timl.lang/Seqable":
      \    {"seq": s:function("s:identity")},
      \  "timl.lang/IPersistentCollection":
      \    {"cons": s:function("s:cons_cons"),
      \     "empty": s:function("s:empty_list")},
      \  "timl.lang/ISeq":
      \    {"first": s:function('s:cons_car'),
      \     "rest": s:function('s:cons_cdr')}}})

" Section: Empty list

let g:timl#lang#EmptyList = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/EmptyList'),
      \ "implements":
      \ {"timl.lang/Seqable":
      \    {"seq": s:function("s:nil")},
      \  "timl.lang/Counted":
      \    {"count": s:function("s:zero")},
      \  "timl.lang/IPersistentCollection":
      \    {"cons": s:function("s:cons_cons"),
      \     "empty": s:function("s:identity")},
      \  "timl.lang/ISeq":
      \    {"first": s:function('s:nil'),
      \     "rest": s:function('s:identity')}}})

let g:timl#empty_list = timl#persistentb(timl#bless('timl.lang/EmptyList', {'count': 0}))

" Section: Chunked Cons

function! s:chunk_first(seq) abort
  return get(a:seq.list, a:seq.pos, g:timl#nil)
endfunction

function! s:chunk_rest(seq) abort
  if len(a:seq.list) - a:seq.pos <= 1
    return a:seq.next
  else
    return g:timl#lang#ChunkedCons.create(a:seq.list, a:seq.next, a:seq.pos+1)
  endif
endfunction

function! s:chunk_count(this) abort
  return len(a:this.list) - a:this.pos + timl#count(a:this.next)
endfunction

let g:timl#lang#ChunkedCons = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/ChunkedCons'),
      \ "implements":
      \ {"timl.lang/Seqable":
      \    {"seq": s:function('s:identity')},
      \  "timl.lang/Counted":
      \    {"count": s:function("s:chunk_count")},
      \  "timl.lang/IPersistentCollection":
      \    {"cons": s:function("s:cons_cons"),
      \     "empty": s:function("s:empty_list")},
      \  "timl.lang/ISeq":
      \    {"first": s:function('s:chunk_first'),
      \     "rest": s:function('s:chunk_rest')}}})

function! g:timl#lang#ChunkedCons.create(list, ...) abort
  return timl#persistentb(timl#bless('timl.lang/ChunkedCons', {
        \ 'list': a:list,
        \ 'pos': a:0 > 1 ? a:2 : 0,
        \ 'next': a:0 ? a:1 : g:timl#nil}))
endfunction

" Section: Lazy Seqs

function! timl#lang#create_lazy_seq(fn)
  let seq = timl#bless('timl.lang/LazySeq', {'fn': a:fn})
  return timl#persistentb(seq)
endfunction

function! s:deref_lazy_seq(lseq) abort
  if !has_key(a:lseq, 'seq')
    try
      unlockvar 1 a:lseq
      let _ = {'seq': timl#call(a:lseq.fn, [])}
      while !timl#satisfiesp('timl.lang/ISeq', _.seq)
        let _.seq = timl#dispatch('timl.lang/Seqable', 'seq', _.seq)
      endwhile
      let a:lseq.seq = _.seq
    finally
      lockvar 1 a:lseq
    endtry
  endif
  return a:lseq.seq
endfunction

let g:timl#lang#LazySeq = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/LazySeq'),
      \ "implements":
      \ {"timl.lang/Seqable":
      \   {"seq": s:function('s:deref_lazy_seq')},
      \  "timl.lang/IPersistentCollection":
      \    {"cons": s:function("s:cons_cons"),
      \     "empty": s:function("s:empty_list")}}})

" Section: Hashes

function! s:map_seq(hash) abort
  let items = map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), '[timl#dekey(v:val[0]), v:val[1]]')
  return empty(items) ? g:timl#nil : g:timl#lang#ChunkedCons.create(items)
endfunction

function! s:map_get(this, key, ...) abort
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

function! s:map_cons(this, x) abort
  return timl#persistentb(extend(timl#transient(a:this), {timl#key(timl#first(a:x)): timl#first(timl#rest(a:x))}))
endfunction

let s:empty_map = timl#persistentb(timl#bless('timl.lang/HashMap'))
function! s:map_empty(this) abort
  return s:empty_map
endfunction

let g:timl#lang#HashMap = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/HashMap'),
      \ "implements":
      \ {"timl.lang/Seqable":
      \    {"seq": s:function('s:map_seq')},
      \  "timl.lang/ILookup":
      \    {"get": s:function('s:map_get')},
      \  "timl.lang/IPersistentCollection":
      \    {"cons": s:function("s:map_cons"),
      \     "empty": s:function("s:map_empty")},
      \  "timl.lang/IFn":
      \    {"invoke": s:function('s:map_get')}}})

function! s:set_seq(hash) abort
  let items = map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), 'v:val[1]')
  return empty(items) ? g:timl#nil : g:timl#lang#ChunkedCons.create(items)
endfunction

function! s:set_get(this, key, ...) abort
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

function! s:set_cons(this, x) abort
  return timl#persistentb(extend(timl#transient(a:this), {timl#key(a:x): a:x}))
endfunction

let s:empty_set = timl#persistentb(timl#bless('timl.lang/HashSet'))
function! s:set_empty(this) abort
  return s:empty_set
endfunction

let g:timl#lang#HashSet = timl#bless(s:type, {
      \ "name": timl#symbol('timl.lang/HashSet'),
      \ "implements":
      \ {"timl.lang/Seqable":
      \    {"seq": s:function("s:set_seq")},
      \  "timl.lang/ILookup":
      \    {"get": s:function('s:set_get')},
      \  "timl.lang/IPersistentCollection":
      \    {"cons": s:function("s:set_cons"),
      \     "empty": s:function("s:set_empty")},
      \  "timl.lang/IFn":
      \    {"invoke": s:function('s:set_get')}}})

" Section: Namespaces

let g:timl#lang#Namespace = timl#bless(s:type, {})

" vim:set et sw=2:
