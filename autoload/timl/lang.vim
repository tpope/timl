" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lang")
  finish
endif
let g:autoloaded_timl_lang = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

if !exists('g:timl#namespaces')
  let g:timl#namespaces = {
        \ 'timl.core': timl#bless('timl.lang/Namespace', {'name': timl#symbol('timl.core'), 'referring': [], 'aliases': {}}),
        \ 'user':      timl#bless('timl.lang/Namespace', {'name': timl#symbol('user'), 'referring': [timl#symbol('timl.core')], 'aliases': {}})}
endif

if !exists('g:timl#core#_STAR_ns_STAR_')
  let g:timl#core#_STAR_ns_STAR_ = g:timl#namespaces['user']
endif

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

function! s:methods(type, ...)
  for i in range(0, a:0-1, 2)
    call timl#type#method(a:000[i], timl#keyword(a:type), a:000[i+1])
  endfor
endfunction

function! s:implement(type, ...)
  let type = timl#keyword(a:type)
  for i in range(0, a:0-1, 2)
    call timl#type#define_method('timl.core', a:000[i], type, a:000[i+1])
  endfor
endfunction

" Section: Nil

function! s:nil_lookup(this, key, default)
  return a:default
endfunction

call s:implement('timl.lang/Nil',
      \ '_seq', s:function('s:nil'),
      \ '_first', s:function('s:nil'),
      \ '_rest', s:function('s:empty_list'),
      \ '_lookup', s:function('s:nil_lookup'))

" Section: Boolean

if !exists('g:timl#false')
  let g:timl#false = timl#bless('timl.lang/Boolean', {'value': 0})
  let g:timl#true = timl#bless('timl.lang/Boolean', {'value': 1})
  lockvar g:timl#false g:timl#true
endif

" Section: Symbols/Keywords

function! s:this_get(this, coll, ...) abort
  if a:0
    return timl#get(a:coll, a:this, a:1)
  else
    return timl#get(a:coll, a:this)
  endif
endfunction

call s:implement('timl.lang/Symbol',
      \ '_invoke', s:function('s:this_get'))

call s:implement('timl.lang/Keyword',
      \ '_invoke', s:function('s:this_get'))

" Section: Function

function! s:function_invoke(this, ...) abort
  return call(a:this.call, a:000, a:this)
endfunction

call s:implement('timl.lang/Function',
      \ '_invoke', s:function('s:function_invoke'))

call s:implement('timl.lang/MultiFn',
      \ '_invoke', s:function('timl#type#dispatch'))

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

call s:implement('timl.lang/Cons',
      \ '_seq', s:function('s:identity'),
      \ '_first', s:function('s:cons_car'),
      \ '_rest', s:function('s:cons_cdr'),
      \ '_conj', s:function('s:cons_cons'),
      \ 'empty', s:function('s:empty_list'))

" Section: Empty list

let g:timl#empty_list = timl#persistentb(timl#bless('timl.lang/EmptyList', {'count': 0}))

call s:implement('timl.lang/EmptyList',
      \ '_seq', s:function('s:nil'),
      \ '_first', s:function('s:nil'),
      \ '_rest', s:function('s:identity'),
      \ '_count', s:function('s:zero'),
      \ '_conj', s:function('s:cons_cons'),
      \ 'empty', s:function('s:identity'))

" Section: Chunked Cons

function! s:chunk_first(seq) abort
  return get(a:seq.list, a:seq.pos, g:timl#nil)
endfunction

function! s:chunk_rest(seq) abort
  if len(a:seq.list) - a:seq.pos <= 1
    return a:seq.next
  else
    return timl#lang#create_chunked_cons(a:seq.list, a:seq.next, a:seq.pos+1)
  endif
endfunction

function! s:chunk_count(this) abort
  return len(a:this.list) - a:this.pos + timl#count(a:this.next)
endfunction

function! timl#lang#create_chunked_cons(list, ...) abort
  return timl#persistentb(timl#bless('timl.lang/ChunkedCons', {
        \ 'list': a:list,
        \ 'pos': a:0 > 1 ? a:2 : 0,
        \ 'next': a:0 ? a:1 : g:timl#nil}))
endfunction

call s:implement('timl.lang/ChunkedCons',
      \ '_seq', s:function('s:identity'),
      \ '_first', s:function('s:chunk_first'),
      \ '_rest', s:function('s:chunk_rest'),
      \ '_count', s:function('s:chunk_count'),
      \ '_conj', s:function('s:cons_cons'),
      \ 'empty', s:function('s:empty_list'))

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
      while !timl#type#canp(_.seq, g:timl#core#_rest)
        let _.seq = timl#type#dispatch(g:timl#core#_seq, _.seq)
      endwhile
      let a:lseq.seq = _.seq
    finally
      lockvar 1 a:lseq
    endtry
  endif
  return a:lseq.seq
endfunction

call s:implement('timl.lang/LazySeq',
      \ '_seq', s:function('s:deref_lazy_seq'),
      \ '_conj', s:function('s:cons_cons'),
      \ 'empty', s:function('s:empty_list'))

" Section: Hash Map

function! s:map_seq(hash) abort
  let items = map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), '[timl#dekey(v:val[0]), v:val[1]]')
  return empty(items) ? g:timl#nil : timl#lang#create_chunked_cons(items)
endfunction

function! s:map_lookup(this, key, ...) abort
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

function! s:map_cons(this, x) abort
  return timl#persistentb(extend(timl#transient(a:this), {timl#key(timl#first(a:x)): timl#first(timl#rest(a:x))}))
endfunction

let s:empty_map = timl#persistentb(timl#bless('timl.lang/HashMap'))
function! s:map_empty(this) abort
  return s:empty_map
endfunction

call s:implement('timl.lang/HashMap',
      \ '_seq', s:function('s:map_seq'),
      \ '_lookup', s:function('s:map_lookup'),
      \ '_conj', s:function('s:map_cons'),
      \ 'empty', s:function('s:map_empty'),
      \ '_invoke', s:function('s:map_lookup'))

" Section: Hash Set

function! s:set_seq(hash) abort
  let items = map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), 'v:val[1]')
  return empty(items) ? g:timl#nil : timl#lang#create_chunked_cons(items)
endfunction

function! s:set_lookup(this, key, ...) abort
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

function! s:set_cons(this, x) abort
  return timl#persistentb(extend(timl#transient(a:this), {timl#key(a:x): a:x}))
endfunction

function! s:set_disj(this, x) abort
  let x = timl#key(a:x)
  if has_key(a:this, x)
    let set = copy(a:this)
    call remove(set, x)
    return timl#persistentb(set)
  endif
  return a:this
endfunction

let s:empty_set = timl#persistentb(timl#bless('timl.lang/HashSet'))
function! s:set_empty(this) abort
  return s:empty_set
endfunction

call s:implement('timl.lang/HashSet',
      \ '_seq', s:function('s:set_seq'),
      \ '_lookup', s:function('s:set_lookup'),
      \ '_conj', s:function('s:set_cons'),
      \ 'empty', s:function('s:set_empty'),
      \ '_disj', s:function('s:set_disj'),
      \ '_invoke', s:function('s:set_lookup'))

" Section: Defaults

runtime! autoload/timl/vim.vim
call timl#type#define_method('timl.core', 'empty', g:timl#nil, s:function('s:nil'))

" vim:set et sw=2:
