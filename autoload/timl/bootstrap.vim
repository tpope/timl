" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lang")
  finish
endif
let g:autoloaded_timl_lang = 1

" Section: Util

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
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

function! s:implement(type, ...) abort
  let type = timl#keyword#intern(a:type)
  for i in range(0, a:0-1, 2)
    call timl#type#define_method('timl.core', a:000[i], type, s:function(a:000[i+1]))
  endfor
endfunction

function! s:intern_fn(name, apply, ...) abort
  let fn = timl#bless('timl.lang/Function', {
          \ 'name': a:name,
          \ 'ns': s:ns})
  let fn.__apply__ = s:function(a:apply)
  if a:0
    let fn.call = s:function(a:1)
  endif
  call timl#namespace#intern(s:ns, a:name, fn)
endfunction

let s:ns = timl#namespace#create(timl#symbol#intern('timl.core'))

function! s:apply(_) dict abort
  return call(self.call, a:_, self)
endfunction

function! s:predicate(_) dict abort
  return call(self.call, a:_, self) ? g:timl#true : g:timl#false
endfunction

let s:k_help = timl#keyword#intern('help')
function! s:define_call(name, fn)
  if a:fn =~# '^[a-z0-9_]\+$'
    let name = timl#symbol#intern_with_meta(a:name, timl#map#create([s:k_help, a:fn.'()']))
  else
    let name = timl#symbol#intern(a:name)
  endif
  call s:intern_fn(name, 's:apply', a:fn)
endfunction

function! s:define_pred(name, fn)
  if a:fn =~# '^[a-z0-9_]\+$'
    let name = timl#symbol#intern_with_meta(a:name, timl#map#create([s:k_help, a:fn.'()']))
  else
    let name = timl#symbol#intern(a:name)
  endif
  call s:intern_fn(name, 's:predicate', a:fn)
endfunction

function! s:define_apply(name, fn) abort
  call s:intern_fn(timl#symbol#intern(a:name), a:fn)
endfunction

" Section: Meta

call timl#type#define_method('timl.core', 'meta', g:timl#nil, s:function('s:nil'))
call s:define_call('vary-meta', 'timl#meta#vary')
call s:define_call('alter-meta!', 'timl#meta#alter')

" Section: Type Sytem

call s:define_call('blessing', 'timl#type#keyword')
call s:define_pred('isa?', 'timl#type#isap')
call s:define_pred('can?', 'timl#type#canp')

" Section: Utility

call s:define_call('munge', 'timl#munge')

" Section: Equality

call s:define_apply('identical?', 'timl#equality#identical')
call s:define_apply('=', 'timl#equality#all')
call s:define_apply('not=', 'timl#equality#not')

" Section: Number

call s:define_call('num', 'timl#num#coerce')
call s:define_call('int', 'timl#number#int')
call s:define_call('float', 'timl#number#float')
call s:define_pred('number?', 'timl#number#test')
call s:define_pred('integer?', 'timl#number#integerp')
call s:define_pred('float?', 'timl#number#floatp')
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
call s:define_call('inc', 'timl#number#inc')
call s:define_call('dec', 'timl#number#dec')
call s:define_call('rem', 'timl#number#rem')
call s:define_call('quot', 'timl#number#quot')
call s:define_call('mod', 'timl#number#mod')
call s:define_call('bit-not', 'timl#number#bit_not')
call s:define_apply('bit-or', 'timl#number#bit_or')
call s:define_apply('bit-xor', 'timl#number#bit_xor')
call s:define_apply('bit-and', 'timl#number#bit_and')
call s:define_apply('bit-and-not', 'timl#number#bit_and_not')
call s:define_call('bit-shift-left', 'timl#number#bit_shift_left')
call s:define_call('bit-shift-right', 'timl#number#bit_shift_right')
call s:define_call('bit-flip', 'timl#number#bit_flip')
call s:define_call('bit-set', 'timl#number#bit_set')
call s:define_call('bit-clear', 'timl#number#bit_clear')
call s:define_pred('bit-test', 'timl#number#bit_test')
call s:define_call('not-negative', 'timl#number#not_negative')
call s:define_pred('zero?', 'timl#number#zerop')
call s:define_pred('nonzero?', 'timl#number#nonzerop')
call s:define_pred('pos?', 'timl#number#posp')
call s:define_pred('neg?', 'timl#number#negp')
call s:define_pred('odd?', 'timl#number#oddp')
call s:define_pred('even?', 'timl#number#evenp')

call s:define_call('str2nr', 'str2nr')
if has('float')
  call s:define_call('str2float', 'str2float')
  call s:define_call('float2nr', 'float2nr')
endif

" Section: String

call s:implement('vim/String',
      \ 'seq', 'timl#string#seq',
      \ 'lookup', 'timl#string#lookup',
      \ 'length', 'timl#string#length')

call s:define_call('symbol', 'timl#symbol#intern')
call s:define_call('keyword', 'timl#keyword#intern')
call s:define_call('gensym', 'timl#symbol#gen')
call s:define_call('format', 'printf')
call s:define_apply('str', 'timl#string#join')
call s:define_call('join', 'timl#string#join')
call s:define_call('split', 'timl#string#split')
call s:define_call('replace', 'timl#string#replace')
call s:define_call('replace-one', 'timl#string#replace_one')
call s:define_call('re-quote-replacement', 'timl#string#re_quote_replacement')
call s:define_call('re-find', 'timl#string#re_find')
call s:define_call('subs', 'timl#string#sub')
call s:define_apply('pr-str', 'timl#string#pr')
call s:define_apply('prn-str', 'timl#string#prn')
call s:define_apply('print-str', 'timl#string#print')
call s:define_apply('println-str', 'timl#string#println')

call s:define_pred('symbol?', 'timl#symbol#test')
call s:define_pred('keyword?', 'timl#keyword#test')
call s:define_pred('string?', 'timl#string#test')

call s:define_call('char2nr', 'char2nr')
call s:define_call('nr2char', 'nr2char')

" Section: Nil

function! s:nilp(this) abort
  return a:this is g:timl#nil
endfunction

function! s:nil_lookup(this, key, default) abort
  return a:default
endfunction

function! s:nil_cons(this, ...) abort
  return call('timl#cons#conj', [g:timl#empty_list] + a:000)
endfunction

function! s:nil_assoc(this, ...) abort
  return timl#map#create(a:000)
endfunction

call s:implement('timl.lang/Nil',
      \ 'seq', 's:nil',
      \ 'first', 's:nil',
      \ 'more', 's:empty_list',
      \ 'conj', 's:nil_cons',
      \ 'assoc', 's:nil_assoc',
      \ 'length', 's:zero',
      \ 'lookup', 's:nil_lookup')

call s:define_pred('nil?', 's:nilp')

" Section: Boolean

if !exists('g:timl#false')
  let g:timl#false = timl#bless('timl.lang/Boolean', {'value': 0})
  let g:timl#true = timl#bless('timl.lang/Boolean', {'value': 1})
  lockvar 1 g:timl#false g:timl#true
endif

call s:define_pred('boolean', 'timl#truth')

" Section: Symbol/Keyword

function! s:this_get(this, coll, ...) abort
  if a:0
    return timl#coll#get(a:coll, a:this, a:1)
  else
    return timl#coll#get(a:coll, a:this)
  endif
endfunction

call s:implement('timl.lang/Symbol',
      \ 'meta', 'timl#meta#from_attribute',
      \ 'with-meta', 'timl#meta#copy_assign_lock',
      \ 'equiv', 'timl#symbol#equal',
      \ 'call', 'timl#keyword#call')

call s:implement('timl.lang/Keyword',
      \ 'call', 'timl#keyword#call')

" Section: Function

call s:implement('timl.lang/Function',
      \ 'call', 'timl#function#call')

call s:implement('timl.lang/MultiFn',
      \ 'call', 'timl#type#dispatch')

call s:implement('vim/Funcref',
      \ 'call', 'timl#funcref#call')

call s:define_apply('apply', 'timl#function#apply')
call s:define_call('identity', 'timl#function#identity')

call s:define_call('fn', 'timl#function#fn')
call s:define_call('defn', 'timl#function#defn')
call s:define_call('defmacro', 'timl#function#defmacro')
for s:x in ['fn', 'defn', 'defmacro']
  let s:y = timl#namespace#maybe_resolve(s:ns, timl#symbol#intern(s:x))
  let s:y.meta = timl#map#create([timl#keyword#intern('macro'), g:timl#true])
endfor
unlet s:x s:y
let g:timl#core#fn.macro = g:timl#true
let g:timl#core#defn.macro = g:timl#true
let g:timl#core#defmacro.macro = g:timl#true

" Section: Namespace

call s:define_apply('load', 'timl#loader#all_relative')
call s:define_apply('require', 'timl#loader#require_all')
call s:define_apply('use', 'timl#loader#use_all')
call s:define_call('create-ns', 'timl#namespace#create')
call s:define_call('find-ns', 'timl#namespace#find')
call s:define_call('the-ns', 'timl#namespace#the')
call s:define_call('ns-name', 'timl#namespace#name')
call s:define_call('all-ns', 'timl#namespace#all')
call s:define_call('in-ns', 'timl#namespace#select')
call s:define_call('refer', 'timl#namespace#refer')
call s:define_call('alias', 'timl#namespace#alias')
call s:define_call('intern', 'timl#namespace#intern')

" Section: Var

call s:implement('timl.lang/Var',
      \ 'meta', 'timl#meta#from_attribute',
      \ 'reset-meta!', 'timl#var#reset_meta',
      \ 'call', 'timl#var#call',
      \ 'deref', 'timl#var#get')
call s:define_call('var-get', 'timl#var#get')
call s:define_call('find-var', 'timl#var#find')
call s:define_pred('var?', 'timl#var#test')

" Section: Array (Vim List)

call s:implement('vim/List',
      \ 'seq', 'timl#array#seq',
      \ 'first', 'timl#array#first',
      \ 'more', 'timl#array#rest',
      \ 'lookup', 'timl#array#lookup',
      \ 'nth', 'timl#array#nth',
      \ 'length', 'len',
      \ 'conj', 'timl#array#conj',
      \ 'empty', 'timl#array#empty')

call s:implement('vim/List',
      \ 'equiv', 'timl#equality#seq',
      \ 'conj!', 'timl#array#conjb',
      \ 'persistent!', 'timl#array#persistentb')

" Section: Vector

call s:implement('timl.lang/Vector',
      \ 'seq', 'timl#vector#seq',
      \ 'first', 'timl#vector#first',
      \ 'more', 'timl#vector#rest',
      \ 'lookup', 'timl#vector#lookup',
      \ 'nth', 'timl#vector#nth',
      \ 'length', 'timl#vector#length',
      \ 'conj', 'timl#vector#conj',
      \ 'empty', 'timl#vector#empty',
      \ 'call', 'timl#vector#call')

call s:implement('timl.lang/Vector',
      \ 'equiv', 'timl#equality#seq',
      \ 'transient', 'timl#vector#transient')

call s:define_call('subvec', 'timl#vector#sub')
call s:define_pred('vector?', 'timl#vectorp')
call s:define_call('vec', 'timl#vec')
call s:define_apply('vector', 'timl#vec')

" Section: Cons

call s:implement('timl.lang/Cons',
      \ 'meta', 'timl#meta#from_attribute',
      \ 'with-meta', 'timl#meta#copy_assign_lock',
      \ 'seq', 'timl#function#identity',
      \ 'equiv', 'timl#equality#seq',
      \ 'first', 'timl#cons#first',
      \ 'more', 'timl#cons#more',
      \ 'conj', 'timl#cons#conj',
      \ 'empty', 's:empty_list')

call s:define_apply('list', 'timl#cons#from_array')
call s:define_pred('list?', 'timl#cons#listp')
call s:define_call('cons', 'timl#cons#create')

" Section: Empty list

if !exists('g:timl#empty_list')
  let g:timl#empty_list = timl#bless('timl.lang/EmptyList', {'count': 0})
  lockvar 1 g:timl#empty_list
endif

call s:implement('timl.lang/EmptyList',
      \ 'meta', 'timl#meta#from_attribute',
      \ 'with-meta', 'timl#meta#copy_assign_lock',
      \ 'seq', 's:nil',
      \ 'equiv', 'timl#equality#seq',
      \ 'first', 's:nil',
      \ 'more', 'timl#function#identity',
      \ 'length', 's:zero',
      \ 'conj', 'timl#cons#conj',
      \ 'empty', 'timl#function#identity')

" Section: Seq

call s:define_call('next', 'timl#next')
call s:define_call('rest', 'timl#rest')
call s:define_pred('empty?', 'timl#emptyp')
call s:define_call('ffirst', 'timl#ffirst')
call s:define_call('fnext', 'timl#fnext')
call s:define_call('nfirst', 'timl#nfirst')
call s:define_call('nnext', 'timl#nnext')
call s:define_call('second', 'timl#fnext')

" Section: Array Seq

call s:implement('timl.lang/ArraySeq',
      \ 'meta', 'timl#meta#from_attribute',
      \ 'with-meta', 'timl#meta#copy_assign_lock',
      \ 'seq', 'timl#function#identity',
      \ 'equiv', 'timl#equality#seq',
      \ 'first', 'timl#array_seq#first',
      \ 'more', 'timl#array_seq#more',
      \ 'length', 'timl#array_seq#length',
      \ 'conj', 'timl#cons#conj',
      \ 'empty', 's:empty_list')

call s:implement('timl.lang/ArraySeq',
      \ 'chunk-first', 'timl#array_seq#chunk_first',
      \ 'chunk-rest', 'timl#array_seq#chunk_rest')

" Section: Chunked Cons

call s:define_call('chunk-cons', 'timl#chunked_cons#create')

call s:implement('timl.lang/ChunkedCons',
      \ 'meta', 'timl#meta#from_attribute',
      \ 'with-meta', 'timl#meta#copy_assign_lock',
      \ 'seq', 'timl#function#identity',
      \ 'equiv', 'timl#equality#seq',
      \ 'first', 'timl#chunked_cons#first',
      \ 'more', 'timl#chunked_cons#more',
      \ 'length', 'timl#chunked_cons#length',
      \ 'conj', 'timl#cons#conj',
      \ 'empty', 's:empty_list')

call s:implement('timl.lang/ChunkedCons',
      \ 'chunk-first', 'timl#chunked_cons#chunk_first',
      \ 'chunk-rest', 'timl#chunked_cons#chunk_rest')

" Section: Lazy Seq

call s:implement('timl.lang/LazySeq',
      \ 'meta', 'timl#meta#from_attribute',
      \ 'with-meta', 'timl#meta#copy_assign',
      \ 'seq', 'timl#lazy_seq#seq',
      \ 'equiv', 'timl#equality#seq',
      \ 'realized?', 'timl#lazy_seq#realized',
      \ 'conj', 'timl#cons#conj',
      \ 'empty', 's:empty_list')

" Section: Dictionary

call s:implement('vim/Dictionary',
      \ 'seq', 'timl#dictionary#seq',
      \ 'lookup', 'timl#dictionary#lookup',
      \ 'empty', 'timl#dictionary#empty',
      \ 'conj', 'timl#dictionary#conj',
      \ 'length', 'len',
      \ 'equiv', 'timl#map#equal')

call s:implement('vim/Dictionary',
      \ 'assoc', 'timl#dictionary#assoc',
      \ 'dissoc', 'timl#dictionary#dissoc',
      \ 'transient', 'timl#dictionary#transient')

call s:implement('vim/Dictionary',
      \ 'conj!', 'timl#dictionary#conjb',
      \ 'assoc!', 'timl#dictionary#assocb',
      \ 'dissoc!', 'timl#dictionary#dissocb',
      \ 'persistent!', 'timl#dictionary#persistentb')

call s:define_pred('dict?', 'timl#dictionary#test')
call s:define_apply('dict', 'timl#dictionary#create')

" Section: Hash Map

call s:implement('timl.lang/HashMap',
      \ 'seq', 'timl#map#seq',
      \ 'lookup', 'timl#map#lookup',
      \ 'empty', 'timl#map#empty',
      \ 'conj', 'timl#map#conj',
      \ 'length', 'timl#map#length',
      \ 'equiv', 'timl#map#equal')

call s:implement('timl.lang/HashMap',
      \ 'assoc', 'timl#map#assoc',
      \ 'dissoc', 'timl#map#dissoc',
      \ 'transient', 'timl#map#transient',
      \ 'call', 'timl#map#call')

call s:implement('timl.lang/HashMap',
      \ 'conj!', 'timl#map#conjb',
      \ 'assoc!', 'timl#map#assocb',
      \ 'dissoc!', 'timl#map#dissocb',
      \ 'persistent!', 'timl#map#persistentb')

call s:define_pred('map?', 'timl#mapp')
call s:define_apply('hash-map', 'timl#map#create')

" Section: Hash Set

call s:implement('timl.lang/HashSet',
      \ 'seq', 'timl#set#seq',
      \ 'lookup', 'timl#set#lookup',
      \ 'empty', 'timl#set#empty',
      \ 'conj', 'timl#set#conj',
      \ 'length', 'timl#set#length',
      \ 'equiv', 'timl#set#equal')

call s:implement('timl.lang/HashSet',
      \ 'disj', 'timl#set#disj',
      \ 'transient', 'timl#set#transient',
      \ 'call', 'timl#set#call')

call s:implement('timl.lang/TransientHashSet',
      \ 'length', 'timl#set#length',
      \ 'lookup', 'timl#set#lookup',
      \ 'conj!', 'timl#set#conjb',
      \ 'disj!', 'timl#set#disjb',
      \ 'persistent!', 'timl#set#persistentb')

call s:define_pred('set?', 'timl#setp')
call s:define_call('set', 'timl#set#coerce')
call s:define_apply('hash-set', 'timl#set#coerce')

" Section: Collection

call s:define_pred('coll?', 'timl#coll#test')
call s:define_pred('chunked-seq?', 'timl#coll#chunked_seqp')
call s:define_call('count', 'timl#coll#count')
call s:define_call('get', 'timl#coll#get')
call s:define_call('into', 'timl#coll#into')
call s:define_call('reduce', 'timl#coll#reduce')
call s:define_pred('contains?', 'timl#coll#containsp')

" Section: Compiler

call s:define_pred('special-symbol?', 'timl#compiler#specialp')
call s:define_call('macroexpand-1', 'timl#compiler#macroexpand_1')
call s:define_call('macroexpand-all', 'timl#compiler#macroexpand_all')

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

" Section: Vim Interop

call s:define_pred('exists?', 'exists')
call s:define_pred('has?', 'has')

" Section: Defaults

call timl#type#define_method('timl.core', 'empty', g:timl#nil, s:function('s:nil'))

call timl#type#define_method('timl.core', 'equiv', g:timl#nil, g:timl#core#identical_QMARK_)

function! s:default_first(x)
  return timl#invoke(g:timl#core#first, timl#invoke(g:timl#core#seq, a:x))
endfunction
call timl#type#define_method('timl.core', 'first', g:timl#nil, s:function('s:default_first'))

" vim:set et sw=2:
