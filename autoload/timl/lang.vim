" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lang")
  finish
endif
let g:autoloaded_timl_lang = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

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

let s:ns = timl#namespace#find('timl.core')
function! s:define_apply(name, fn)
  let g:timl#core#{timl#munge(a:name)} = timl#bless('timl.lang/Function', {
        \ 'name': timl#symbol#intern(a:name),
        \ 'ns': s:ns,
        \ 'apply': s:function(a:fn)})
endfunction

function! s:apply(_) abort
  return call(self.call, a:_, self)
endfunction

function! s:define_call(name, fn)
  let g:timl#core#{timl#munge(a:name)} = timl#bless('timl.lang/Function', {
        \ 'name': timl#symbol#intern(a:name),
        \ 'ns': s:ns,
        \ 'apply': s:function('s:apply'),
        \ 'call': s:function(a:fn)})
endfunction

function! s:define_apply(name, fn)
  let g:timl#core#{timl#munge(a:name)} = timl#bless('timl.lang/Function', {
        \ 'name': timl#symbol#intern(a:name),
        \ 'ns': s:ns,
        \ 'apply': s:function(a:fn)})
endfunction

" Section: Number

call s:define_apply('+', 'timl#number#sum')
call s:define_apply('*', 'timl#number#product')
call s:define_apply('-', 'timl#number#minus')
call s:define_apply('/', 'timl#number#solidus')
call s:define_apply('>', 'timl#number#gt')
call s:define_apply('<', 'timl#number#lt')
call s:define_apply('>=', 'timl#number#gteq')
call s:define_apply('<=', 'timl#number#lteq')
call s:define_apply('==', 'timl#number#equiv')
call s:define_apply('max', 'max')
call s:define_apply('min', 'min')

" Section: Nil

function! s:nil_lookup(this, key, default)
  return a:default
endfunction

function! s:nil_cons(this, ...)
  return call('timl#cons#conj', [g:timl#empty_list] + a:000)
endfunction

function! s:nil_assoc(this, ...)
  return timl#map#create(a:000)
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

" Section: Symbol/Keyword

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
  return a:this.apply(a:000)
endfunction

call s:implement('timl.lang/Function',
      \ '_invoke', s:function('s:function_invoke'))

call s:implement('timl.lang/MultiFn',
      \ '_invoke', s:function('timl#type#dispatch'))

" Section: Array (Vim List)

call s:implement('vim/List',
      \ 'seq', s:function('timl#array#seq'),
      \ 'first', s:function("timl#array#first"),
      \ 'more', s:function("timl#array#rest"),
      \ 'lookup', s:function('timl#array#lookup'),
      \ 'nth', s:function('timl#array#nth'),
      \ 'count', s:function('len'),
      \ 'conj', s:function('timl#array#cons'),
      \ 'empty', s:function('timl#array#empty'),
      \ '_invoke', s:function('timl#array#lookup'))

call s:implement('vim/List',
      \ 'transient', s:function('timl#array#transient'),
      \ 'conj!', s:function('timl#array#conjb'),
      \ 'persistent!', s:function('timl#array#persistentb'))

" Section: Cons

call s:implement('timl.lang/Cons',
      \ 'seq', s:function('s:identity'),
      \ 'first', s:function('timl#cons#first'),
      \ 'more', s:function('timl#cons#more'),
      \ 'conj', s:function('timl#cons#conj'),
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
      \ 'conj', s:function('timl#cons#conj'),
      \ 'empty', s:function('s:identity'))

" Section: Array Seq

call s:implement('timl.lang/ArraySeq',
      \ 'seq', s:function('s:identity'),
      \ 'first', s:function('timl#array_seq#first'),
      \ 'more', s:function('timl#array_seq#more'),
      \ 'count', s:function('timl#array_seq#count'),
      \ 'conj', s:function('timl#cons#conj'),
      \ 'empty', s:function('s:empty_list'))

" Section: Lazy Seq

call s:implement('timl.lang/LazySeq',
      \ 'seq', s:function('timl#lazy_seq#seq'),
      \ 'realized?', s:function('timl#lazy_seq#realized'),
      \ 'count', s:function('timl#lazy_seq#count'),
      \ 'conj', s:function('timl#cons#conj'),
      \ 'empty', s:function('s:empty_list'))

" Section: Dictionary

call s:implement('vim/Dictionary',
      \ 'seq', s:function('timl#dictionary#seq'),
      \ 'lookup', s:function('timl#dictionary#lookup'),
      \ 'empty', s:function('timl#dictionary#empty'),
      \ 'conj', s:function('timl#dictionary#conj'),
      \ 'assoc', s:function('timl#dictionary#assoc'),
      \ 'dissoc', s:function('timl#dictionary#dissoc'),
      \ 'transient', s:function('timl#dictionary#transient'),
      \ 'invoke', s:function('timl#dictionary#lookup'))

call s:implement('vim/Dictionary',
      \ 'conj!', s:function('timl#dictionary#conjb'),
      \ 'assoc!', s:function('timl#dictionary#assocb'),
      \ 'dissoc!', s:function('timl#dictionary#dissocb'),
      \ 'persistent!', s:function('timl#dictionary#persistentb'))

" Section: Hash Map

call s:implement('timl.lang/HashMap',
      \ 'seq', s:function('timl#map#seq'),
      \ 'lookup', s:function('timl#map#lookup'),
      \ 'empty', s:function('timl#map#empty'),
      \ 'conj', s:function('timl#map#conj'),
      \ 'assoc', s:function('timl#map#assoc'),
      \ 'dissoc', s:function('timl#map#dissoc'),
      \ 'transient', s:function('timl#map#transient'),
      \ 'invoke', s:function('timl#map#lookup'))

call s:implement('timl.lang/HashMap',
      \ 'conj!', s:function('timl#map#conjb'),
      \ 'assoc!', s:function('timl#map#assocb'),
      \ 'dissoc!', s:function('timl#map#dissocb'),
      \ 'persistent!', s:function('timl#map#persistentb'))

" Section: Hash Set

call s:implement('timl.lang/HashSet',
      \ 'seq', s:function('timl#set#seq'),
      \ 'lookup', s:function('timl#set#lookup'),
      \ 'empty', s:function('timl#set#empty'),
      \ 'conj', s:function('timl#set#conj'),
      \ 'disj', s:function('timl#set#disj'),
      \ 'transient', s:function('timl#set#transient'),
      \ '_invoke', s:function('timl#set#lookup'))

call s:implement('timl.lang/HashSet',
      \ 'conj!', s:function('timl#set#conjb'),
      \ 'disj!', s:function('timl#set#disjb'),
      \ 'persistent!', s:function('timl#set#persistentb'))

" Section: I/O

call s:define_apply('echo', 'timl#io#echo')
call s:define_apply('echon', 'timl#io#echon')
call s:define_apply('echomsg', 'timl#io#echomsg')
call s:define_apply('print', 'timl#io#echon')
call s:define_apply('println', 'timl#io#println')
call s:define_call('newline', 'timl#io#newline')
call s:define_call('printf', 'timl#io#printf')
call s:define_apply('pr', 'timl#io#pr')
call s:define_apply('prn', 'timl#io#prn')
call s:define_call('spit', 'timl#io#spit')
call s:define_call('slurp', 'timl#io#slurp')
call s:define_call('read-string', 'timl#reader#read_string')

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
