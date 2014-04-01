" Maintainer: Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_bootstrap")
  finish
endif
let g:autoloaded_timl_bootstrap = 1

" Section: Setup

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

function! s:implement(type, ...) abort
  let type = timl#symbol#intern(a:type)
  for i in range(0, a:0-1, 2)
    call timl#type#define_method(s:ns, timl#symbol#intern(a:000[i]), type, s:function(a:000[i+1]))
  endfor
endfunction

let s:fn_type = timl#type#core_create('Function')
function! s:intern_fn(name, apply, ...) abort
  let fn = {'name': a:name, 'ns': s:ns}
  if a:0
    call extend(fn, a:1)
  endif
  call timl#type#bless(s:fn_type, fn)
  let fn.__call__ = s:function(a:apply)
  call timl#namespace#intern(s:ns, a:name, fn)
endfunction

let s:ns = timl#namespace#create(timl#symbol#intern('timl.core'))
let s:langns = timl#namespace#create(timl#symbol#intern('timl.lang'))
let s:vimns = timl#namespace#create(timl#symbol#intern('vim'))

function! s:apply(_) dict abort
  return call(self.invoke, a:_, self)
endfunction

function! s:predicate(_) dict abort
  return call(self.test, a:_, self) ? g:timl#true : g:timl#false
endfunction

let s:k_help = timl#keyword#intern('help')
function! s:define_call(name, fn) abort
  if a:fn =~# '^[a-z0-9_]\+$'
    let name = timl#symbol#intern_with_meta(a:name, timl#map#create([s:k_help, a:fn.'()']))
  else
    let name = timl#symbol#intern(a:name)
  endif
  call s:intern_fn(name, 's:apply', {'invoke': s:function(a:fn)})
endfunction

function! s:define_pred(name, fn) abort
  if a:fn =~# '^[a-z0-9_]\+$'
    let name = timl#symbol#intern_with_meta(a:name, timl#map#create([s:k_help, a:fn.'()']))
  else
    let name = timl#symbol#intern(a:name)
  endif
  call s:intern_fn(name, 's:predicate', {'test': s:function(a:fn)})
endfunction

function! s:define_apply(name, fn) abort
  call s:intern_fn(timl#symbol#intern(a:name), a:fn)
endfunction

" Section: Namespace

call s:define_apply('load', 'timl#loader#all_relative')
call s:define_apply('require', 'timl#loader#require_all')
call s:define_apply('use', 'timl#loader#use_all')
call s:define_call('create-ns', 'timl#namespace#create')
call s:define_call('find-ns', 'timl#namespace#find')
call s:define_call('the-ns', 'timl#namespace#the')
call s:define_call('ns-name', 'timl#namespace#name')
call s:define_call('ns-map', 'timl#namespace#map')
call s:define_call('ns-aliases', 'timl#namespace#aliases')
call s:define_call('all-ns', 'timl#namespace#all')
call s:define_call('in-ns', 'timl#namespace#select')
call s:define_call('refer', 'timl#namespace#refer')
call s:define_call('alias', 'timl#namespace#alias')
call s:define_call('intern', 'timl#namespace#intern')

" Section: Var

call s:define_call('var-get', 'timl#var#get')
call s:define_call('find-var', 'timl#var#find')
call s:define_pred('var?', 'timl#var#test')
call s:define_call('munge', 'timl#var#munge')

" Section: Type Sytem

call s:define_pred('isa?', 'timl#type#isap')
call s:define_pred('can?', 'timl#type#canp')

call s:implement('timl.lang/Type',
      \ 'hash', 'timl#hash#str_attribute',
      \ 'call', 'timl#function#call')

" Section: Meta

call s:define_call('meta', 'timl#meta#get')
call s:define_call('vary-meta', 'timl#meta#vary')
call s:define_call('alter-meta!', 'timl#meta#alter')

" Section: Symbol/Keyword

call s:define_call('symbol', 'timl#symbol#intern')
call s:define_call('keyword', 'timl#keyword#intern')
call s:define_call('gensym', 'timl#symbol#gen')
call s:define_pred('symbol?', 'timl#symbol#test')
call s:define_pred('keyword?', 'timl#keyword#test')

" Section: Equality

call s:define_apply('identical?', 'timl#equality#identical')
call s:define_apply('=', 'timl#equality#all')
call s:define_apply('not=', 'timl#equality#not')

" Section: Nil

call s:define_pred('nil?', 'timl#nil#test')
call timl#nil#identity()

" Section: Number

call timl#type#define(s:vimns, timl#symbol('Number'), g:timl#nil)
call s:implement('vim/Number',
      \ 'hash', 'timl#function#identity',
      \ 'to-string', 'string')

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
  call timl#type#define(s:vimns, timl#symbol('Float'), g:timl#nil)
  call s:implement('vim/Float',
        \ 'to-string', 'string')
  call s:define_call('str2float', 'str2float')
  call s:define_call('float2nr', 'float2nr')
endif

" Section: String

call timl#type#define(s:vimns, timl#symbol('String'), g:timl#nil)

call s:implement('vim/String',
      \ 'to-string', 'timl#function#identity',
      \ 'hash', 'timl#hash#string',
      \ 'funcref', 'function',
      \ 'seq', 'timl#string#seq',
      \ 'lookup', 'timl#string#lookup',
      \ 'length', 'timl#string#length')

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

call s:define_pred('string?', 'timl#string#test')

call s:define_call('char2nr', 'char2nr')
call s:define_call('nr2char', 'nr2char')

" Section: Boolean

let s:boolean = timl#type#core_define('Boolean', g:timl#nil, {
      \ 'hash': 'len'})

if !exists('g:timl#false')
  call timl#false#identity()
  call timl#true#identity()
endif

call s:define_pred('boolean', 'timl#truth')
call s:define_pred('false?', 'timl#false#test')
call s:define_pred('true?', 'timl#true#test')

" Section: Function

call timl#type#define(s:vimns, timl#symbol('Funcref'), g:timl#nil)

call s:implement('timl.lang/Function',
      \ 'hash', 'timl#function#hash',
      \ 'call', 'timl#function#call')

call s:implement('timl.lang/MultiFn',
      \ 'hash', 'timl#function#hash',
      \ 'call', 'timl#type#dispatch')

call s:implement('vim/Funcref',
      \ 'funcref', 'timl#function#identity',
      \ 'to-string', 'timl#funcref#string',
      \ 'hash', 'timl#funcref#hash',
      \ 'call', 'timl#funcref#call')

call s:define_pred('funcref?', 'timl#funcref#test')

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

" Section: Array (Vim List)

call timl#type#define(s:vimns, timl#symbol('List'), g:timl#nil)
call s:implement('vim/List',
      \ 'seq', 'timl#array#seq',
      \ 'car', 'timl#array#car',
      \ 'cdr', 'timl#array#cdr',
      \ 'lookup', 'timl#array#lookup',
      \ 'nth', 'timl#array#nth',
      \ 'length', 'len',
      \ 'conj', 'timl#array#conj',
      \ 'empty', 'timl#array#empty')

call s:implement('vim/List',
      \ 'equiv', 'timl#equality#seq',
      \ 'conj!', 'timl#array#conjb',
      \ 'assoc!', 'timl#array#assocb',
      \ 'dissoc!', 'timl#array#dissocb',
      \ 'persistent!', 'timl#array#persistentb')

call s:define_apply('array', 'timl#array#coerce')

" Section: Vector

call timl#type#define(s:langns, timl#symbol('Vector'), g:timl#nil)

call s:implement('timl.lang/Vector',
      \ 'seq', 'timl#vector#seq',
      \ 'car', 'timl#vector#car',
      \ 'cdr', 'timl#vector#cdr',
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
call s:define_pred('vector?', 'timl#vector#test')
call s:define_call('vec', 'timl#vector#coerce')
call s:define_apply('vector', 'timl#vector#coerce')

" Section: Cons

call s:define_call('cons', 'timl#cons#create')
call s:define_apply('list*', 'timl#cons#spread')

" Section: List

let g:timl#empty_list = timl#list#empty()

call s:define_apply('list', 'timl#list#create')
call s:define_pred('list?', 'timl#list#test')

" Section: Seq

call s:define_call('first', 'timl#coll#first')
call s:define_call('next', 'timl#coll#next')
call s:define_call('rest', 'timl#coll#rest')
call s:define_pred('empty?', 'timl#coll#emptyp')
call s:define_call('ffirst', 'timl#coll#ffirst')
call s:define_call('fnext', 'timl#coll#fnext')
call s:define_call('nfirst', 'timl#coll#nfirst')
call s:define_call('nnext', 'timl#coll#nnext')
call s:define_call('second', 'timl#coll#fnext')

" Section: Chunked Cons

call s:define_call('chunk-cons', 'timl#chunked_cons#create')

" Section: Dictionary

call timl#type#define(s:vimns, timl#symbol('Dictionary'), g:timl#nil)
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

call timl#type#define(s:langns, timl#symbol('HashMap'), g:timl#nil)

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
      \ 'call', 'timl#map#call')

call s:define_pred('map?', 'timl#map#test')
call s:define_apply('hash-map', 'timl#map#create')
call s:define_call('zipmap', 'timl#map#zip')

" Section: Hash Set

call s:define_pred('set?', 'timl#set#test')
call s:define_call('set', 'timl#set#coerce')
call s:define_apply('hash-set', 'timl#set#coerce')
runtime! autoload/timl/set.vim

" Section: Collection

call s:define_pred('coll?', 'timl#coll#test')
call s:define_pred('seq?', 'timl#coll#seqp')
call s:define_pred('sequential?', 'timl#coll#sequentialp')
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

" Section: Reference types

call s:define_call('force', 'timl#delay#force')
call s:define_call('future-call', 'timl#future#call')
runtime! autoload/timl/atom.vim

" Section: Time

call s:define_call('inst', 'timl#inst#create')
call s:define_call('sleep', 'timl#inst#sleep')

" Section: Vim Interop

call s:define_pred('exists?', 'exists')
call s:define_pred('has?', 'has')

" vim:set et sw=2:
