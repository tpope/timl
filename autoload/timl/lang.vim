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
    call timl#type#method(a:000[i], timl#keyword#intern(a:type), a:000[i+1])
  endfor
endfunction

function! s:implement(type, ...)
  let type = timl#keyword#intern(a:type)
  for i in range(0, a:0-1, 2)
    call timl#type#define_method('timl.core', a:000[i], type, a:000[i+1])
  endfor
endfunction

" Section: Nil

function! s:nil_lookup(this, key, default)
  return a:default
endfunction

function! s:nil_cons(this, ...)
  return call('s:cons_cons', [g:timl#empty_list] + a:000)
endfunction

function! s:nil_assoc(this, ...)
  return call('s:map_assoc', [timl#hash_map()] + a:000)
endfunction

call s:implement('timl.lang/Nil',
      \ 'seq', s:function('s:nil'),
      \ 'first', s:function('s:nil'),
      \ 'more', s:function('s:empty_list'),
      \ 'conj', s:function('s:nil_cons'),
      \ 'assoc', s:function('s:nil_assoc'),
      \ 'count', s:function('s:zero'),
      \ 'lookup', s:function('s:nil_lookup'))

" Section: Boolean

if !exists('g:timl#false')
  let g:timl#false = timl#bless('timl.lang/Boolean', {'value': 0})
  let g:timl#true = timl#bless('timl.lang/Boolean', {'value': 1})
  lockvar 1 g:timl#false g:timl#true
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

function! s:cons_cons(this, ...)
  let head = a:this
  let _ = {}
  for _.e in a:000
    let head = timl#cons(_.e, head)
  endfor
  return head
endfunction

call s:implement('timl.lang/Cons',
      \ 'seq', s:function('s:identity'),
      \ 'first', s:function('s:cons_car'),
      \ 'more', s:function('s:cons_cdr'),
      \ 'conj', s:function('s:cons_cons'),
      \ 'empty', s:function('s:empty_list'))

" Section: Empty list

if !exists('g:timl#empty_list')
  let g:timl#empty_list = timl#bless('timl.lang/EmptyList', {'count': 0})
  lockvar 1 g:timl#empty_list
endif

call s:implement('timl.lang/EmptyList',
      \ 'seq', s:function('s:nil'),
      \ 'first', s:function('s:nil'),
      \ 'more', s:function('s:identity'),
      \ 'count', s:function('s:zero'),
      \ 'conj', s:function('s:cons_cons'),
      \ 'empty', s:function('s:identity'))

" Section: Array Seq

call s:implement('timl.lang/ArraySeq',
      \ 'seq', s:function('s:identity'),
      \ 'first', s:function('timl#array_seq#first'),
      \ 'more', s:function('timl#array_seq#more'),
      \ 'count', s:function('timl#array_seq#count'),
      \ 'conj', s:function('s:cons_cons'),
      \ 'empty', s:function('s:empty_list'))

" Section: Lazy Seq

call s:implement('timl.lang/LazySeq',
      \ 'seq', s:function('timl#lazy_seq#seq'),
      \ 'realized?', s:function('timl#lazy_seq#realized'),
      \ 'count', s:function('timl#lazy_seq#count'),
      \ 'conj', s:function('s:cons_cons'),
      \ 'empty', s:function('s:empty_list'))

" Section: Hash Map

function! s:map_seq(hash) abort
  let items = map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), '[timl#dekey(v:val[0]), v:val[1]]')
  return empty(items) ? g:timl#nil : timl#array_seq#create(items)
endfunction

function! s:map_lookup(this, key, ...) abort
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

function! s:map_cons(this, ...) abort
  let this = copy(a:this)
  let _ = {}
  for _.e in a:000
    let this[timl#key(timl#first(_.e))] = timl#fnext(_.e)
  endfor
  lockvar 1 this
  return this
endfunction

function! s:map_assoc(this, ...) abort
  let this = copy(a:this)
  let _ = {}
  for i in range(0, len(a:000)-2, 2)
    let this[timl#key(a:000[i])] = a:000[i+1]
  endfor
  lockvar 1 this
  return this
endfunction

function! s:map_dissoc(this, ...) abort
  let _ = {}
  let this = copy(a:this)
  for _.x in a:000
    let key = timl#key(_.x)
    if has_key(this, key)
      call remove(this, key)
    endif
  endfor
  lockvar 1 this
  return this
endfunction

let s:empty_map = timl#persistentb(timl#bless('timl.lang/HashMap'))
function! s:map_empty(this) abort
  return s:empty_map
endfunction

call s:implement('timl.lang/HashMap',
      \ 'seq', s:function('s:map_seq'),
      \ 'lookup', s:function('s:map_lookup'),
      \ 'empty', s:function('s:map_empty'),
      \ 'conj', s:function('s:map_cons'),
      \ 'assoc', s:function('s:map_assoc'),
      \ 'dissoc', s:function('s:map_dissoc'),
      \ 'invoke', s:function('s:map_lookup'))

" Section: Hash Set

function! s:set_seq(hash) abort
  let items = map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), 'v:val[1]')
  return empty(items) ? g:timl#nil : timl#array_seq#create(items)
endfunction

function! s:set_lookup(this, key, ...) abort
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

function! s:set_cons(this, ...) abort
  let this = copy(a:this)
  let _ = {}
  for _.e in a:000
    let this[timl#key(_.e)] = _.e
  endfor
  lockvar 1 this
  return this
endfunction


function! s:set_disj(this, ...) abort
  let _ = {}
  let this = copy(a:this)
  for _.x in a:000
    let key = timl#key(_.x)
    if has_key(this, key)
      call remove(this, key)
    endif
  endfor
  lockvar 1 this
  return this
endfunction

let s:empty_set = timl#persistentb(timl#bless('timl.lang/HashSet'))
function! s:set_empty(this) abort
  return s:empty_set
endfunction

call s:implement('timl.lang/HashSet',
      \ 'seq', s:function('s:set_seq'),
      \ 'lookup', s:function('s:set_lookup'),
      \ 'empty', s:function('s:set_empty'),
      \ 'conj', s:function('s:set_cons'),
      \ 'disj', s:function('s:set_disj'),
      \ '_invoke', s:function('s:set_lookup'))

" Section: Defaults

runtime! autoload/timl/vim.vim
call timl#type#define_method('timl.core', 'empty', g:timl#nil, s:function('s:nil'))

function! s:default_first(x)
  return timl#type#dispatch(g:timl#core#first, timl#type#dispatch(g:timl#core#seq, a:x))
endfunction
call timl#type#define_method('timl.core', 'first', g:timl#nil, s:function('s:default_first'))

function! s:default_count(x)
  return 1 + timl#type#dispatch(g:timl#core#count, timl#type#dispatch(g:timl#core#more, a:x))
endfunction
call timl#type#define_method('timl.core', 'count', g:timl#nil, s:function('s:default_count'))

" vim:set et sw=2:
