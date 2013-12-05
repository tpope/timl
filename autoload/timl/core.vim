if exists("g:autoloaded_timl_core") || &cp || v:version < 700
  finish
endif
let g:autoloaded_timl_core = 1

let s:fn = timl#intern_type('timl#lang#Function')

let s:true = g:timl#true
let s:false = g:timl#false

let s:dict = {}

command! -bang -nargs=1 TLfunction
      \ let g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')} = {
      \    '#tag': s:fn,
      \    'ns': 'timl#core',
      \    'name': timl#demunge(matchstr(<q-args>, '^\zs[[:alnum:]_]\+')),
      \    'call': function('timl#core#'.matchstr(<q-args>, '^[[:alnum:]_#]\+'))} |
      \ function<bang> timl#core#<args> abort

command! -bang -nargs=+ TLalias
      \ let g:timl#core#{[<f-args>][0]} = {
      \    '#tag': s:fn,
      \    'ns': 'timl#core',
      \    'name': timl#demunge(([<f-args>][0])),
      \    'call': function([<f-args>][1])}

command! -bang -nargs=1 TLexpr
      \ exe "function! s:dict.call".matchstr(<q-args>, '([^)]*)')." abort\nreturn".matchstr(<q-args>, ')\zs.*')."\nendfunction" |
      \ let g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')} = {
      \    '#tag': s:fn,
      \    'ns': 'timl#core',
      \    'name': timl#demunge(matchstr(<q-args>, '^\zs[[:alnum:]_]\+')),
      \    'call': s:dict.call}

command! -bang -nargs=1 TLpredicate TLexpr <args> ? s:true : s:false

" Section: Types {{{1

TLexpr type(val) timl#symbol(timl#type(a:val))
TLpredicate nil_QMARK_(val)     a:val is# g:timl#nil
TLpredicate symbol_QMARK_(obj)  timl#symbolp(a:obj)
TLpredicate str_QMARK_(obj)     type(a:obj) == type('')
TLpredicate integer_QMARK_(obj) type(a:obj) == type(0)
TLpredicate float_QMARK_(obj)   type(a:obj) == 5
TLpredicate number_QMARK_(obj)  type(a:obj) == type(0) || type(a:obj) == 5

TLfunction! number(obj) abort
  if type(a:obj) == type(0) || type(a:obj) == 5
    return a:obj
  else
    throw "timl: not a number"
  endif
endfunction

TLalias symbol timl#symbol

TLfunction! str(...) abort
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

TLexpr identity(x) a:x

TLfunction! apply(f, x, ...) abort
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

TLfunction! echo(...) abort
  echo call('timl#core#str', a:000, {})
  return g:timl#nil
endfunction

TLfunction! echomsg(...) abort
  echomsg call('timl#core#str', a:000, {})
  return g:timl#nil
endfunction

" }}}1
" Section: Operators {{{

TLfunction! _PLUS_(...) abort
  let acc = 0
  for elem in a:000
    let acc += elem
  endfor
  return acc
endfunction

TLfunction! _STAR_(...) abort
  let acc = 1
  for elem in a:000
    let acc = acc * elem
  endfor
  return acc
endfunction

TLfunction! _(x, ...) abort
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

TLfunction! _SLASH_(x, ...) abort
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

TLexpr rem(x, y) timl#core#number(a:x) % a:y

TLfunction! _GT_(x, y) abort
  return timl#core#number(a:x) ># timl#core#number(a:y) ? s:true : s:false
endfunction

TLfunction! _LT_(x, y) abort
  return timl#core#number(a:x) <# timl#core#number(a:y) ? s:true : s:false
endfunction

TLfunction! _GT__EQ_(x, y) abort
  return timl#core#number(a:x) >=# timl#core#number(a:y) ? s:true : s:false
endfunction

TLfunction! _LT__EQ_(x, y) abort
  return timl#core#number(a:x) <=# timl#core#number(a:y) ? s:true : s:false
endfunction

TLfunction! _EQ_(x, ...) abort
  for y in a:000
    if type(a:x) != type(y) || a:x !=# y
      return s:false
    endif
  endfor
  return s:true
endfunction

TLfunction! _EQ__EQ_(x, ...) abort
  let x = timl#core#number(a:x)
  for y in a:000
    if x != timl#core#number(y)
      return s:false
    endif
  endfor
  return s:true
endfunction

TLfunction! identical_QMARK_(x, ...) abort
  for y in a:000
    if a:x isnot# y
      return s:false
    endif
  endfor
  return s:true
endfunction

" }}}1
" Section: Lists {{{1

TLalias list timl#list
TLalias list_STAR_ timl#list2
TLpredicate list_QMARK_(val) timl#consp(a:val)
TLalias cons timl#cons

TLfunction! append(...) abort
  let acc = []
  let _ = {}
  for _.elem in a:000
    call extend(acc, timl#vec(_.elem))
  endfor
  return timl#lock(acc)
endfunction

" }}}1
" Section: Vectors {{{1

TLpredicate vector_QMARK_(val) timl#vectorp(a:val)
TLalias vector timl#persist
TLalias vec timl#vec

TLfunction! subvec(list, start, ...) abort
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

TLfunction! dict(...) abort
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

TLfunction! hash_map(...) abort
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

TLfunction! dict_QMARK_(val) abort
  return type(a:val) == type({}) ? s:true : s:false
endfunction

TLfunction! dissoc(dict, ...) abort
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

TLalias get timl#get

TLfunction! empty(coll) abort
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

TLalias seq timl#seq
TLalias first timl#first
TLalias rest timl#rest
TLalias next timl#next

TLfunction! partition(n, seq) abort
  let seq = timl#core#vec(a:seq)
  let out = []
  for i in range(0, len(seq)-1, a:n)
    call add(out, seq[i : i+a:n-1])
  endfor
  return out
endfunction

TLalias count timl#count

TLexpr empty_QMARK_(coll) empty(timl#core#seq(a:coll))

TLfunction! map(f, coll) abort
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
  let tag = timl#intern_type('timl#lang#Cons')
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

TLfunction! reduce(f, coll, ...) abort
  let _ = {}
  if a:0
    let _.val = a:coll
    let _.seq = timl#seq(a:1)
  else
    let _.seq = timl#seq(a:coll)
    if empty(_.seq)
      return g:timl#nil
    endif
    let _.val = timl#first(_.seq)
    let _.seq = timl#rest(_.seq)
  endif
  while _.seq isnot# g:timl#nil
    let _.val = timl#call(a:f, [_.val, timl#first(_.seq)])
    let _.seq = timl#next(_.seq)
  endwhile
  return _.val
endfunction

" }}}1
" Section: Namespaces {{{1

TLexpr require(ns)  timl#require(timl#str(a:ns))

TLfunction! in_ns(ns) abort
  call timl#create_ns(timl#core#str(a:ns))
  let g:timl#core#_STAR_ns_STAR_ = timl#symbol(a:ns)
  return g:timl#core#_STAR_ns_STAR_
endfunction

TLfunction! refer(ns) abort
  let me = timl#core#str(g:timl#core#_STAR_ns_STAR_)
  call timl#create_ns(me, {'referring': [a:ns]})
  return g:timl#nil
endfunction

TLfunction! alias(alias, ns) abort
  let me = timl#core#str(g:timl#core#_STAR_ns_STAR_)
  call timl#create_ns(me, {'aliases': {timl#core#str(a:alias): a:ns}})
  return g:timl#nil
endfunction

" }}}1

delcommand TLfunction
delcommand TLalias
delcommand TLexpr
delcommand TLpredicate

call timl#source_file(expand('<sfile>:r') . '.macros.tim', 'timl#core')
call timl#source_file(expand('<sfile>:r') . '.basics.tim', 'timl#core')
call timl#source_file(expand('<sfile>:r') . '.seq.tim', 'timl#core')
call timl#source_file(expand('<sfile>:r') . '.coll.tim', 'timl#core')
call timl#source_file(expand('<sfile>:r') . '.vim.tim', 'timl#core')

" vim:set et sw=2:
