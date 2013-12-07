" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lang")
  finish
endif
let g:autoloaded_timl_lang = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

" Section: Nil

function! s:identity(x)
  return a:x
endfunction

function! s:nil_get(this, key, ...)
  return a:0 ? a:1 : g:timl#nil
endfunction

let g:timl#lang#Nil = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": s:function("s:identity")},
      \  "timl#lang#ISeq":
      \    {"first": s:function('s:identity'),
      \     "rest": s:function('s:identity')},
      \ "timl#lang#ILookup":
      \    {"get": s:function('s:nil_get')}}}

" Section: Symbol

function! s:this_get(this, coll, ...) abort
  if a:0
    return timl#dispatch('timl#lang#ILookup', 'get', a:coll, a:this, a:1)
  else
    return timl#dispatch('timl#lang#ILookup', 'get', a:coll, a:this)
  endif
endfunction

let g:timl#lang#Symbol = {
      \ "implements":
      \ {"timl#lang#IFn":
      \    {"invoke": s:function('s:this_get')}}}

let g:timl#lang#Keyword = {
      \ "implements":
      \ {"timl#lang#IFn":
      \    {"invoke": s:function('s:this_get')}}}

" Section: Function

function! s:function_invoke(this, ...) abort
  return call(a:this.call, a:000, a:this)
endfunction

let g:timl#lang#Function = {
      \ "implements":
      \ {"timl#lang#IFn":
      \    {"invoke": s:function('s:function_invoke')}}}

" Section: Cons

function! s:cons_car(cons)
  return a:cons.car
endfunction

function! s:cons_cdr(cons)
  return timl#seq(a:cons.cdr)
endfunction

let g:timl#lang#Cons = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": s:function("s:identity")},
      \  "timl#lang#ISeq":
      \    {"first": s:function('s:cons_car'),
      \     "rest": s:function('s:cons_cdr')}}}

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

let g:timl#lang#ChunkedCons = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": s:function('s:identity')},
      \  "timl#lang#ISeq":
      \    {"first": s:function('s:chunk_first'),
      \     "rest": s:function('s:chunk_rest')}}}

function! g:timl#lang#ChunkedCons.create(list, ...) abort
  return timl#persistentb({'#tag': timl#intern_type('timl#lang#ChunkedCons'),
        \ 'list': a:list,
        \ 'pos': a:0 > 1 ? a:2 : 0,
        \ 'next': a:0 ? a:1 : g:timl#nil})
endfunction

" Section: Lazy Seqs

function! timl#lang#create_lazy_seq(fn)
  let seq = {'#tag': timl#intern_type('timl#lang#LazySeq'), 'fn': a:fn}
  lockvar seq
  return seq
endfunction

function! s:deref_lazy_seq(lseq) abort
  if !has_key(a:lseq, 'seq')
    unlockvar a:lseq
    let _ = {'seq': timl#call(a:lseq.fn, [])}
    while !timl#satisfiesp('timl#lang#ISeq', _.seq)
      let _.seq = timl#dispatch('timl#lang#Seqable', 'seq', _.seq)
    endwhile
    let a:lseq.seq = _.seq
    lockvar a:lseq
  endif
  return a:lseq.seq
endfunction

let g:timl#lang#LazySeq = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \   {"seq": s:function('s:deref_lazy_seq')}}}

" Section: Hashes

function! s:map_seq(hash)
  return timl#list2(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), '[timl#dekey(v:val[0]), v:val[1]]'))
endfunction

function! s:map_get(this, key, ...)
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

let g:timl#lang#HashMap = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": s:function('s:map_seq')},
      \  "timl#lang#ILookup":
      \    {"get": s:function('s:map_get')},
      \  "timl#lang#IFn":
      \    {"invoke": s:function('s:map_get')}}}

function! s:set_seq(hash)
  return timl#list2(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), 'v:val[1]'))
endfunction

function! s:set_get(this, key, ...)
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

let g:timl#lang#HashSet = {
      \ "implements":
      \ {"timl#lang#Seqable":
      \    {"seq": s:function("s:set_seq")},
      \  "timl#lang#ILookup":
      \    {"get": s:function('s:set_get')},
      \  "timl#lang#IFn":
      \    {"invoke": s:function('s:set_get')}}}

" Section: Namespaces

let g:timl#lang#Namespace = {}

" vim:set et sw=2:
