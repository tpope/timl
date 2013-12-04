if exists("g:autoloaded_timl_core") || &cp || v:version < 700
  finish
endif
let g:autoloaded_timl_core = 1

let s:true = g:timl#true
let s:false = g:timl#false

" Section: Types {{{1

function! timl#core#type(val) abort
  return timl#symbol(timl#type(a:val))
endfunction

function! timl#core#nil_QMARK_(val) abort
  return a:val is# g:timl#nil
endfunction

function! timl#core#symbol_QMARK_(obj) abort
  return timl#symbolp(a:obj)
endfunction

function! timl#core#str_QMARK_(obj) abort
  return type(a:obj) == type('') ? s:true : s:false
endfunction

function! timl#core#integer_QMARK_(obj) abort
  return type(a:obj) == type(0)
endfunction

function! timl#core#float_QMARK_(obj) abort
  return type(a:obj) == 5
endfunction

function! timl#core#number_QMARK_(obj) abort
  return type(a:obj) == type(0) || type(a:obj) == 5
endfunction

function! timl#core#number(obj) abort
  if type(a:obj) == type(0) || type(a:obj) == 5
    return a:obj
  else
    throw "timl: not a number"
  endif
endfunction

function! timl#core#symbol(str) abort
  return timl#symbol(a:str)
endfunction

function! timl#core#str(...) abort
  let acc = ''
  let _ = {}
  for _.x in a:000
    if timl#symbolp(_.x)
      let acc .= substitute(_.x[0], '^:', '', '')
    elseif type(_.x) == type('')
      let acc .= _.x
    elseif type(_.x) == type(function('tr'))
      return substitute(join([_.x]), '[{}]', '', 'g')
    else
      let acc .= string(_.x)
    endif
  endfor
  return acc
endfunction

" }}}1
" Section: Functional {{{1

function! timl#core#identity(x) abort
  return a:x
endfunction

function! timl#core#apply(f, x, ...) abort
  let args = [a:x] + a:000
  if timl#type(args[-1]) == 'timl#vim#Dictionary'
    let dict = remove(args, -1)
  else
    let dict = 0
  endif
  let args = args[0:-2] + timl#core#vec(args[-1])
  return timl#call(a:f, args, dict)
endfunction

function! timl#core#throw(val) abort
  throw a:val
endfunction

" }}}1
" Section: IO {{{1

function! timl#core#echo(...) abort
  echo call('timl#core#str', a:000, {})
  return g:timl#nil
endfunction

function! timl#core#echomsg(...) abort
  echomsg call('timl#core#str', a:000, {})
  return g:timl#nil
endfunction

" }}}1
" Section: Operators {{{

function! timl#core#_PLUS_(...) abort
  let acc = 0
  for elem in a:000
    let acc += elem
  endfor
  return acc
endfunction

function! timl#core#_STAR_(...) abort
  let acc = 1
  for elem in a:000
    let acc = acc * elem
  endfor
  return acc
endfunction

function! timl#core#_(x, ...) abort
  if a:0
    let acc = timl#core#number(a:x)
    for elem in a:000
      let acc -= elem
    endfor
    return acc
  else
    return 0 - a:x
  endif
endfunction

function! timl#core#_SLASH_(x, ...) abort
  if a:0
    let acc = timl#core#number(a:x)
    for elem in a:000
      let acc = acc / elem
    endfor
    return acc
  else
    return 1 / a:x
  endif
endfunction

function! timl#core#rem(x, y) abort
  return timl#core#number(a:x) % a:y
endfunction

function! timl#core#_GT_(x, y) abort
  return timl#core#number(a:x) ># timl#core#number(a:y) ? s:true : s:false
endfunction

function! timl#core#_LT_(x, y) abort
  return timl#core#number(a:x) <# timl#core#number(a:y) ? s:true : s:false
endfunction

function! timl#core#_GT__EQ_(x, y) abort
  return timl#core#number(a:x) >=# timl#core#number(a:y) ? s:true : s:false
endfunction

function! timl#core#_LT__EQ_(x, y) abort
  return timl#core#number(a:x) <=# timl#core#number(a:y) ? s:true : s:false
endfunction

function! timl#core#_EQ_(x, ...) abort
  for y in a:000
    if type(a:x) != type(y) || a:x !=# y
      return s:false
    endif
  endfor
  return s:true
endfunction

function! timl#core#_EQ__EQ_(x, ...) abort
  let x = timl#core#number(a:x)
  for y in a:000
    if x != timl#core#number(y)
      return s:false
    endif
  endfor
  return s:true
endfunction

function! timl#core#identical_QMARK_(x, ...) abort
  for y in a:000
    if a:x isnot# y
      return s:false
    endif
  endfor
  return s:true
endfunction

" }}}1
" Section: Lists {{{1

function! timl#core#car(list) abort
  return timl#car(a:list)
endfunction

function! timl#core#cdr(list) abort
  return timl#cdr(a:list)
endfunction

function! timl#core#list(...) abort
  return timl#list2(a:000)
endfunction

function! timl#core#list_STAR_(seq) abort
  return timl#list2(a:seq)
endfunction

function! timl#core#list_QMARK_(val) abort
  return timl#consp(a:val) ? s:true : s:false
endfunction

function! timl#core#append(...) abort
  let acc = []
  let _ = {}
  for _.elem in a:000
    call extend(acc, timl#vec(_.elem))
  endfor
  return timl#lock(acc)
endfunction

function! timl#core#cons(val, seq) abort
  return timl#cons(a:val, timl#core#seq(a:seq))
endfunction

" }}}1
" Section: Vectors {{{1

function! timl#core#vector_QMARK_(val) abort
  return timl#vectorp(a:val) ? s:true : s:false
endfunction

function! timl#core#vector(...) abort
  return timl#persist(a:000)
endfunction

function! timl#core#vec(seq) abort
  if timl#truth(timl#core#vector_QMARK_(type(a:seq)))
    return a:seq
  else
    return timl#vec(timl#core#seq(a:seq))
  endif
endfunction

function! timl#core#subvec(list, start, ...) abort
  if a:0 && a:1 == 0
    return type(a:list) == type('') ? '' : timl#lock([])
  elseif a:0
    return timl#lock(a:list[a:start : (a:1 < 0 ? a:1 : a:1-1)])
  else
    return timl#lock(a:list[a:start :])
  endif
endfunction

" }}}1
" Section: Dictionaries {{{1

function! timl#core#dict(...) abort
  let list = copy(a:000)
  while len(a:000) % 2 !=# 0 && type(list[-1]) == type([])
    call extend(list, timl#vec(remove(list, -1)))
  endwhile
  if len(list) % 2 !=# 0
    throw 'timl: dict requires a even number of arguments'
  endif
  let dict = {}
  for i in range(0, len(list)-1, 2)
    let dict[timl#core#str(list[i])] = list[i+1]
  endfor
  return timl#lock(dict)
endfunction

function! timl#core#hash_map(...) abort
  let list = copy(a:000)
  while len(a:000) % 2 !=# 0 && timl#core#list_QMARK_(list[-1])
    call extend(list, remove(list, -1))
  endwhile
  if len(list) % 2 !=# 0
    throw 'timl: dict requires a even number of arguments'
  endif
  let dict = {}
  for i in range(0, len(list)-1, 2)
    let dict[timl#key(list[i])] = list[i+1]
  endfor
  return timl#lock(dict)
endfunction

function! timl#core#dict_QMARK_(val) abort
  return type(a:val) == type({})
endfunction

function! timl#core#dissoc(dict, ...) abort
  let dict = copy(a:dict)
  let _ = {}
  for _.key in a:000
    let key = timl#key(_.key)
    if has_key(dict, key)
      call remove(dict, key)
    endif
  endfor
  return timl#lock(dict)
endfunction

" }}}1
" Section: Collections {{{1

function! timl#core#get(coll, key, ...) abort
  let def = a:0 ? a:1 : g:timl#nil
  let t = timl#type(a:coll)
  if t ==# 'timl#vim#List'
    if type(a:key) != type(0)
      return a:0 ? a:1 : g:timl#nil
    endif
    return get(a:coll, a:key, def)
  elseif t ==# 'timl#vim#Dictionary'
    return get(a:coll, timl#core#str(a:key), def)
  elseif t !~# '^timl#vim#'
    return get(a:coll, timl#key(a:key), def)
  endif
  return def
endfunction

function! timl#core#assoc(coll, ...) abort
  return timl#lock(extend(timl#core#dict(a:000), a:dict, 'keep'))
endfunction

" }}}1
" Section: Sequences {{{1

function! timl#core#seq(coll)
  let seq = timl#dispatch("timl#lang#Seqable", "seq", a:coll)
  return empty(seq) ? g:timl#nil : seq
endfunction

function! timl#core#first(list) abort
  return timl#dispatch('timl#lang#Seq', 'first', timl#core#seq(a:list))
endfunction

function! timl#core#rest(list) abort
  return timl#dispatch('timl#lang#Seq', 'rest', timl#core#seq(a:list))
endfunction

function! timl#core#length(coll) abort
  let t = timl#type(a:coll)
  if t !~# '^timl#vim'
    return len(a:coll) - 1
  endif
  return len(a:coll)
endfunction

function! timl#core#partition(n, seq) abort
  let seq = timl#core#vec(a:seq)
  let out = []
  for i in range(0, len(seq)-1, a:n)
    call add(out, seq[i : i+a:n-1])
  endfor
  return out
endfunction

function! timl#core#count(list) abort
  return timl#count(a:list)
endfunction

function! timl#core#empty_QMARK_(coll)
  return timl#core#length(a:coll) ? s:false : s:true
endfunction

function! timl#core#empty(coll) abort
  if type(a:coll) == type({})
    return {}
  elseif type(a:coll) == type('')
    return ''
  elseif type(a:coll) == type([]) && !timl#symbolp(a:coll)
    return []
  endif
  return g:timl#nil
endfunction

function! timl#core#map(f, coll) abort
  if type(a:coll) == type([]) && !empty(a:coll) && !timl#symbolp(a:coll)
    let result = map(copy(a:coll), 'timl#call(a:f, [v:val])')
    lockvar result
    return result
  endif
  let _ = {}
  let _.seq = timl#core#seq(a:coll)
  if empty(_.seq)
    return a:coll
  endif
  let tag = timl#symbol('#timl#lang#Cons')
  let head = {'#tag': tag,
        \ 'car': timl#call(a:f, [timl#core#first(_.seq)]),
        \ 'cdr': g:timl#nil}
  let ptr = head
  let _.seq = timl#core#next(_.seq)
  while _.seq isnot# g:timl#nil
    let next = timl#core#next(_.seq)
    let ptr.cdr = {'#tag': tag,
          \ 'car': timl#call(a:f, [timl#core#first(next)]),
          \ 'cdr': g:timl#nil}
    lockvar ptr
    let _.seq = timl#core#next(_.seq)
  endwhile
  lockvar ptr
  return head
endfunction

function! timl#core#reduce(f, coll, ...) abort
  let _ = {}
  if a:0
    let _.val = a:coll
    let _.seq = timl#core#seq(a:1)
  else
    let _.seq = timl#core#seq(a:coll)
    if empty(_.seq)
      return g:timl#nil
    endif
    let _.val = timl#core#first(_.seq)
    let _.seq = timl#core#rest(_.seq)
  endif
  while _.seq isnot# g:timl#nil
    let _.val = timl#call(a:f, [_.val, timl#core#first(_.seq)])
    let _.seq = timl#core#next(_.seq)
  endwhile
  return _.val
endfunction

" }}}1
" Section: Namespaces {{{1

function! timl#core#in_ns(ns)
  call timl#create_ns(timl#core#str(a:ns))
  let g:timl#core#_STAR_ns_STAR_ = timl#symbol(a:ns)
  return g:timl#core#_STAR_ns_STAR_
endfunction

function! timl#core#refer(ns)
  let me = timl#core#str(g:timl#core#_STAR_ns_STAR_)
  call timl#create_ns(me, {'referring': [a:ns]})
  return g:timl#nil
endfunction

function! timl#core#alias(alias, ns)
  let me = timl#core#str(g:timl#core#_STAR_ns_STAR_)
  call timl#create_ns(me, {'aliases': {timl#core#str(a:alias): a:ns}})
  return g:timl#nil
endfunction

" }}}1

call timl#source_file(expand('<sfile>:r') . '.macros.tim', 'timl#core')
call timl#source_file(expand('<sfile>:r') . '.basics.tim', 'timl#core')
call timl#source_file(expand('<sfile>:r') . '.seq.tim', 'timl#core')
call timl#source_file(expand('<sfile>:r') . '.coll.tim', 'timl#core')
call timl#source_file(expand('<sfile>:r') . '.vim.tim', 'timl#core')

" vim:set et sw=2:
