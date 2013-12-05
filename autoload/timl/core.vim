if exists("g:autoloaded_timl_core") || &cp || v:version < 700
  finish
endif
let g:autoloaded_timl_core = 1

let s:fn = timl#symbol('#timl#lang#Function')

let s:true = g:timl#true
let s:false = g:timl#false

command! -bar -bang -nargs=1 TLfunction
      \ let g:{matchstr(<q-args>, '^[[:alnum:]_#]\+')} = {
      \    '#tag': s:fn,
      \    'ns': matchstr(<q-args>, '^[[:alnum:]_#]\+\ze#'),
      \    'name': timl#demunge(matchstr(<q-args>, '^[[:alnum:]_#]\+#\zs[[:alnum:]_]*')),
      \    'call': function(matchstr(<q-args>, '^[[:alnum:]_#]\+'))} |
      \ function<bang> <args>

" Section: Types {{{1

TLfunction! timl#core#type(val) abort
  return timl#symbol(timl#type(a:val))
endfunction

TLfunction! timl#core#nil_QMARK_(val) abort
  return a:val is# g:timl#nil
endfunction

TLfunction! timl#core#symbol_QMARK_(obj) abort
  return timl#symbolp(a:obj)
endfunction

TLfunction! timl#core#str_QMARK_(obj) abort
  return type(a:obj) == type('') ? s:true : s:false
endfunction

TLfunction! timl#core#integer_QMARK_(obj) abort
  return type(a:obj) == type(0)
endfunction

TLfunction! timl#core#float_QMARK_(obj) abort
  return type(a:obj) == 5
endfunction

TLfunction! timl#core#number_QMARK_(obj) abort
  return type(a:obj) == type(0) || type(a:obj) == 5
endfunction

TLfunction! timl#core#number(obj) abort
  if type(a:obj) == type(0) || type(a:obj) == 5
    return a:obj
  else
    throw "timl: not a number"
  endif
endfunction

TLfunction! timl#core#symbol(str) abort
  return timl#symbol(a:str)
endfunction

TLfunction! timl#core#str(...) abort
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

TLfunction! timl#core#identity(x) abort
  return a:x
endfunction

TLfunction! timl#core#apply(f, x, ...) abort
  let args = [a:x] + a:000
  if timl#type(args[-1]) == 'timl#vim#Dictionary'
    let dict = remove(args, -1)
  else
    let dict = 0
  endif
  let args = args[0:-2] + timl#core#vec(args[-1])
  return timl#call(a:f, args)
endfunction

" }}}1
" Section: IO {{{1

TLfunction! timl#core#echo(...) abort
  echo call('timl#core#str', a:000, {})
  return g:timl#nil
endfunction

TLfunction! timl#core#echomsg(...) abort
  echomsg call('timl#core#str', a:000, {})
  return g:timl#nil
endfunction

" }}}1
" Section: Operators {{{

TLfunction! timl#core#_PLUS_(...) abort
  let acc = 0
  for elem in a:000
    let acc += elem
  endfor
  return acc
endfunction

TLfunction! timl#core#_STAR_(...) abort
  let acc = 1
  for elem in a:000
    let acc = acc * elem
  endfor
  return acc
endfunction

TLfunction! timl#core#_(x, ...) abort
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

TLfunction! timl#core#_SLASH_(x, ...) abort
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

TLfunction! timl#core#rem(x, y) abort
  return timl#core#number(a:x) % a:y
endfunction

TLfunction! timl#core#_GT_(x, y) abort
  return timl#core#number(a:x) ># timl#core#number(a:y) ? s:true : s:false
endfunction

TLfunction! timl#core#_LT_(x, y) abort
  return timl#core#number(a:x) <# timl#core#number(a:y) ? s:true : s:false
endfunction

TLfunction! timl#core#_GT__EQ_(x, y) abort
  return timl#core#number(a:x) >=# timl#core#number(a:y) ? s:true : s:false
endfunction

TLfunction! timl#core#_LT__EQ_(x, y) abort
  return timl#core#number(a:x) <=# timl#core#number(a:y) ? s:true : s:false
endfunction

TLfunction! timl#core#_EQ_(x, ...) abort
  for y in a:000
    if type(a:x) != type(y) || a:x !=# y
      return s:false
    endif
  endfor
  return s:true
endfunction

TLfunction! timl#core#_EQ__EQ_(x, ...) abort
  let x = timl#core#number(a:x)
  for y in a:000
    if x != timl#core#number(y)
      return s:false
    endif
  endfor
  return s:true
endfunction

TLfunction! timl#core#identical_QMARK_(x, ...) abort
  for y in a:000
    if a:x isnot# y
      return s:false
    endif
  endfor
  return s:true
endfunction

" }}}1
" Section: Lists {{{1

TLfunction! timl#core#car(list) abort
  return timl#car(a:list)
endfunction

TLfunction! timl#core#cdr(list) abort
  return timl#cdr(a:list)
endfunction

TLfunction! timl#core#list(...) abort
  return timl#list2(a:000)
endfunction

TLfunction! timl#core#list_STAR_(seq) abort
  return timl#list2(a:seq)
endfunction

TLfunction! timl#core#list_QMARK_(val) abort
  return timl#consp(a:val) ? s:true : s:false
endfunction

TLfunction! timl#core#append(...) abort
  let acc = []
  let _ = {}
  for _.elem in a:000
    call extend(acc, timl#vec(_.elem))
  endfor
  return timl#lock(acc)
endfunction

TLfunction! timl#core#cons(val, seq) abort
  return timl#cons(a:val, a:seq)
endfunction

" }}}1
" Section: Vectors {{{1

TLfunction! timl#core#vector_QMARK_(val) abort
  return timl#vectorp(a:val) ? s:true : s:false
endfunction

TLfunction! timl#core#vector(...) abort
  return timl#persist(a:000)
endfunction

TLfunction! timl#core#vec(seq) abort
  if timl#truth(timl#core#vector_QMARK_(type(a:seq)))
    return a:seq
  else
    return timl#vec(timl#core#seq(a:seq))
  endif
endfunction

TLfunction! timl#core#subvec(list, start, ...) abort
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

TLfunction! timl#core#dict(...) abort
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

TLfunction! timl#core#hash_map(...) abort
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

TLfunction! timl#core#dict_QMARK_(val) abort
  return type(a:val) == type({})
endfunction

TLfunction! timl#core#dissoc(dict, ...) abort
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

TLfunction! timl#core#get(coll, key, ...) abort
  if a:0
    return timl#dispatch('timl#lang#ILookup', 'get', a:coll, a:key, a:1)
  else
    return timl#dispatch('timl#lang#ILookup', 'get', a:coll, a:key)
  endif
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

TLfunction! timl#core#assoc(coll, ...) abort
  return timl#lock(extend(timl#core#dict(a:000), a:dict, 'keep'))
endfunction

TLfunction! timl#core#empty(coll) abort
  if timl#consp(a:coll)
    " TODO: empty list
    return g:timl#nil
  endif
  if type(a:coll) == type({})
    return {}
  elseif type(a:coll) == type('')
    return ''
  elseif type(a:coll) == type([]) && !timl#symbolp(a:coll)
    return []
  endif
  return g:timl#nil
endfunction

" }}}1
" Section: Sequences {{{1

TLfunction! timl#core#seq(coll)
  return timl#seq(a:coll)
endfunction

TLfunction! timl#core#first(list) abort
  return timl#dispatch('timl#lang#ISeq', 'first', timl#core#seq(a:list))
endfunction

TLfunction! timl#core#rest(list) abort
  return timl#dispatch('timl#lang#ISeq', 'rest', timl#core#seq(a:list))
endfunction

TLfunction! timl#core#partition(n, seq) abort
  let seq = timl#core#vec(a:seq)
  let out = []
  for i in range(0, len(seq)-1, a:n)
    call add(out, seq[i : i+a:n-1])
  endfor
  return out
endfunction

TLfunction! timl#core#count(seq) abort
  let i = 0
  let _ = {'seq': a:seq}
  while timl#consp(_.seq)
    let i += 1
    let _.seq = timl#cdr(_.seq)
  endwhile
  return i + len(_.seq)
endfunction

TLfunction! timl#core#empty_QMARK_(coll)
  return empty(timl#core#seq(a:coll))
endfunction

TLfunction! timl#core#map(f, coll) abort
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
    let ptr.cdr = {'#tag': tag,
          \ 'car': timl#call(a:f, [timl#core#first(_.seq)]),
          \ 'cdr': g:timl#nil}
    lockvar ptr
    unlockvar 1 ptr
    let ptr = ptr.cdr
    let _.seq = timl#core#next(_.seq)
  endwhile
  lockvar ptr
  return head
endfunction

TLfunction! timl#core#reduce(f, coll, ...) abort
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

TLfunction! timl#core#require(ns) abort
  call timl#require(timl#str(a:ns))
  return g:timl#nil
endfunction

TLfunction! timl#core#in_ns(ns) abort
  call timl#create_ns(timl#core#str(a:ns))
  let g:timl#core#_STAR_ns_STAR_ = timl#symbol(a:ns)
  return g:timl#core#_STAR_ns_STAR_
endfunction

TLfunction! timl#core#refer(ns) abort
  let me = timl#core#str(g:timl#core#_STAR_ns_STAR_)
  call timl#create_ns(me, {'referring': [a:ns]})
  return g:timl#nil
endfunction

TLfunction! timl#core#alias(alias, ns) abort
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
