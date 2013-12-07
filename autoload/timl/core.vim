if exists("g:autoloaded_timl_core") || &cp || v:version < 700
  finish
endif
let g:autoloaded_timl_core = 1

let s:fn = timl#intern_type('timl.lang/Function')

let s:true = g:timl#true
let s:false = g:timl#false

let s:dict = {}

if !exists('g:timl_functions')
  let g:timl_functions = {}
endif

command! -bang -nargs=1 TLfunction
      \ let g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')} = {
      \    '#tag': s:fn,
      \    'ns': 'timl.core',
      \    'name': timl#demunge(matchstr(<q-args>, '^\zs[[:alnum:]_]\+')),
      \    'call': function('timl#core#'.matchstr(<q-args>, '^[[:alnum:]_#]\+'))} |
      \ function! timl#core#<args> abort

command! -bang -nargs=+ TLalias
      \ let g:timl#core#{[<f-args>][0]} = {
      \    '#tag': s:fn,
      \    'ns': 'timl.core',
      \    'name': timl#demunge(([<f-args>][0])),
      \    'call': function([<f-args>][1])}

command! -bang -nargs=1 TLexpr
      \ exe "function! s:dict.call".matchstr(<q-args>, '([^)]*)')." abort\nreturn".matchstr(<q-args>, ')\zs.*')."\nendfunction" |
      \ let g:timl#core#{matchstr(<q-args>, '^[[:alnum:]_]\+')} = {
      \    '#tag': s:fn,
      \    'ns': 'timl.core',
      \    'name': timl#demunge(matchstr(<q-args>, '^\zs[[:alnum:]_]\+')),
      \    'call': s:dict.call} |
      \ let g:timl_functions[join([s:dict.call])] = {'file': expand('<sfile>'), 'line': expand('<slnum>')}

command! -bang -nargs=1 TLpredicate TLexpr <args> ? s:true : s:false

" Section: Misc {{{1

TLpredicate nil_QMARK_(val) a:val is# g:timl#nil
TLexpr type(val) g:{timl#munge(timl#type(a:val))}
TLalias meta timl#meta
TLalias with_meta timl#with_meta
TLalias persistent_BANG_ timl#persistentb
TLalias transient timl#transient

" }}}1
" Section: Functions {{{1

let s:def = timl#symbol('def')
let s:lets = timl#symbol('let*')
let s:fns = timl#symbol('fn*')
let s:fn1 = timl#symbol('timl.core/fn')
let s:defn = timl#symbol('timl.core/defn')
let s:setq = timl#symbol('set!')
let s:dot = timl#symbol('.')
let s:form = timl#symbol('&form')
let s:env = timl#symbol('&env')

TLfunction fn(form, env, ...)
  return timl#with_meta(timl#list2([s:fns] + a:000), timl#meta(a:form))
endfunction
let g:timl#core#fn.macro = g:timl#true

TLfunction defn(form, env, name, ...)
  return timl#list(s:def, a:name, timl#with_meta(timl#list2([s:fn1, a:name] + a:000), timl#meta(a:form)))
endfunction
let g:timl#core#defn.macro = g:timl#true

TLfunction defmacro(form, env, name, params, ...)
  let extra = [s:form, s:env]
  if type(a:params) == type([])
    let body = [extra + a:params] + a:000
  else
    let _ = {}
    let body = []
    for _.list in [a:params] + a:000
      call add(body, timl#cons(extra + timl#first(_.list), timl#next(_.list)))
    endfor
  endif
  let fn = timl#gensym('fn')
  return timl#list(s:lets,
        \ [fn, timl#list2([s:defn, a:name] + body)],
        \ timl#list(s:setq, timl#list(s:dot, fn, timl#symbol('macro')), 1),
        \ fn)
endfunction
let g:timl#core#defmacro.macro = g:timl#true

TLexpr identity(x) a:x

TLfunction! apply(f, x, ...) abort
  let args = [a:x] + a:000
  if timl#type(args[-1]) == 'timl.vim/Dictionary'
    let dict = remove(args, -1)
  else
    let dict = 0
  endif
  let args = args[0:-2] + timl#core#vec(args[-1])
  return timl#call(a:f, args)
endfunction

" }}}1
" Section: IO {{{1

TLfunction echon(...)
  echon join(map(copy(a:000), 'timl#str(v:val)'), ' ')
  return g:timl#nil
endfunction

TLfunction echo(...)
  echo join(map(copy(a:000), 'timl#str(v:val)'), ' ')
  return g:timl#nil
endfunction

TLfunction echomsg(...)
  echomsg join(map(copy(a:000), 'timl#str(v:val)'), ' ')
  return g:timl#nil
endfunction

TLfunction print(...)
  echon join(map(copy(a:000), 'timl#str(v:val)'), ' ')
  return g:timl#nil
endfunction

TLfunction println(...)
  echon join(map(copy(a:000), 'timl#str(v:val)'), ' ')."\n"
  return g:timl#nil
endfunction

TLfunction newline()
  echon "\n"
  return g:timl#nil
endfunction

TLfunction printf(fmt, ...) abort
  echon call('printf', [timl#str(a:fmt)] + a:000)."\n"
  return g:timl#nil
endfunction

TLfunction pr(...)
  echon join(map(copy(a:000), 'timl#printer#string(v:val)'), ' ')
  return g:timl#nil
endfunction

TLfunction prn(...)
  echon join(map(copy(a:000), 'timl#printer#string(v:val)'), ' ')."\n"
  return g:timl#nil
endfunction

TLfunction spit(filename, body)
  if type(body) == type([])
    call writefile(body, a:filename)
  else
    call writefile(split(body, "\n"), a:filename, 'b')
endfunction

TLexpr slurp(filename) join(readfile(a:filename, 'b'), "\n")

TLalias read_string timl#reader#read_string

" }}}1
" Section: Equality {{{1

TLpredicate _EQ_(...)     call('timl#equalsp', a:000)
TLpredicate not_EQ_(...) !call('timl#equalsp', a:000)

TLfunction! identical_QMARK_(x, ...) abort
  for y in a:000
    if a:x isnot# y
      return s:false
    endif
  endfor
  return s:true
endfunction

" }}}1
" Section: Numbers {{{

TLalias num timl#num
TLalias int timl#int
TLalias float timl#float
TLpredicate integer_QMARK_(obj) type(a:obj) == type(0)
TLpredicate float_QMARK_(obj)   type(a:obj) == 5
TLpredicate number_QMARK_(obj)  type(a:obj) == type(0) || type(a:obj) == 5

TLfunction _PLUS_(...)
  let acc = 0
  for elem in a:000
    let acc += elem
  endfor
  return acc
endfunction

TLfunction _STAR_(...)
  let acc = 1
  for elem in a:000
    let acc = acc * elem
  endfor
  return acc
endfunction

TLfunction _(x, ...)
  if a:0
    let acc = timl#num(a:x)
    for elem in a:000
      let acc -= elem
    endfor
    return acc
  else
    return 0 - a:x
  endif
endfunction

TLfunction _SLASH_(x, ...)
  if a:0
    let acc = timl#num(a:x)
    for elem in a:000
      let acc = acc / elem
    endfor
    return acc
  else
    return 1 / a:x
  endif
endfunction

TLexpr inc(x) timl#num(a:x) + 1
TLexpr dec(x) timl#num(a:x) - 1
TLexpr rem(x, y) timl#num(a:x) % a:y
TLexpr quot(x, y) type(a:x) == 5 || type(a:y) == type(5) ? trunc(a:x/a:y) : timl#num(a:x)/a:y
TLfunction mod(x, y)
  if (timl#num(a:x) < 0 && timl#num(a:y) > 0 || timl#num(a:x) > 0 && timl#num(a:y) < 0) && a:x % a:y != 0
    return (a:x % a:y) + a:y
  else
    return a:x % a:y
  endif
endfunction

TLexpr min(...) min(a:000)
TLexpr max(...) max(a:000)

TLexpr bit_not(x) invert(a:x)
TLexpr bit_or(x, y, ...)  a:0 ? call(self.call, [ or(a:x, a:y)] + a:000, self) :  or(a:x, a:y)
TLexpr bit_xor(x, y, ...) a:0 ? call(self.call, [xor(a:x, a:y)] + a:000, self) : xor(a:x, a:y)
TLexpr bit_and(x, y, ...) a:0 ? call(self.call, [and(a:x, a:y)] + a:000, self) : and(a:x, a:y)
TLexpr bit_and_not(x, y, ...) a:0 ? call(self.call, [and(a:x, invert(a:y))] + a:000, self) : and(a:x, invert(a:y))
TLfunction bit_shift_left(x, n)
  let x = timl#int(a:x)
  for i in range(timl#int(a:n))
    let x = x * 2
  endfor
  return x
endfunction
TLfunction bit_shift_right(x, n)
  let x = timl#int(a:x)
  for i in range(timl#int(a:n))
    let x = x / 2
  endfor
  return x
endfunction
TLexpr bit_flip(x, n)  xor(a:x, g:timl#core#bit_shift_left.call(1, a:n))
TLexpr bit_set(x, n)    or(a:x, g:timl#core#bit_shift_left.call(1, a:n))
TLexpr bit_clear(x, n) and(a:x, invert(g:timl#core#bit_shift_left.call(1, a:n)))
TLpredicate bit_test(x, n) and(a:x, g:timl#core#bit_shift_left.call(1, a:n))

TLexpr      not_negative(x) timl#num(a:x) < 0 ? g:timl#nil : a:x
TLpredicate zero_QMARK_(x) timl#num(a:x) == 0
TLpredicate nonzero_QMARK_(x) timl#num(a:x) != 0
TLpredicate pos_QMARK_(x) timl#num(a:x) > 0
TLpredicate neg_QMARK_(x) timl#num(a:x) < 0
TLpredicate odd_QMARK_(x) timl#num(a:x) % 2
TLpredicate even_QMARK_(x) timl#num(a:x) % 2 == 0

TLfunction _GT_(x, ...)
  let x = timl#num(a:x)
  for y in a:000
    if !(timl#num(x) > y)
      return s:false
    endif
    let x = y
  endfor
  return s:true
endfunction

TLfunction _LT_(x, ...)
  let x = timl#num(a:x)
  for y in a:000
    if !(timl#num(x) < y)
      return s:false
    endif
    let x = y
  endfor
  return s:true
endfunction

TLfunction _GT__EQ_(x, ...)
  let x = timl#num(a:x)
  for y in a:000
    if !(timl#num(x) >= y)
      return s:false
    endif
    let x = y
  endfor
  return s:true
endfunction

TLfunction _LT__EQ_(x, ...)
  let x = timl#num(a:x)
  for y in a:000
    if !(timl#num(x) <= y)
      return s:false
    endif
    let x = y
  endfor
  return s:true
endfunction

TLfunction _EQ__EQ_(x, ...)
  let x = timl#num(a:x)
  for y in a:000
    if x != timl#num(y)
      return s:false
    endif
  endfor
  return s:true
endfunction

" }}}1
" Section: Strings {{{1

TLpredicate string_QMARK_(obj)  type(a:obj) == type('')
TLpredicate symbol_QMARK_(obj)  timl#symbolp(a:obj)
TLpredicate keyword_QMARK_(obj) timl#keywordp(a:obj)

TLalias name    timl#name
TLalias symbol  timl#symbol
TLalias keyword timl#keyword

TLexpr pr_str(...) join(map(copy(a:000), 'timl#printer#string(v:val)'), ' ')
TLexpr prn_str(...) join(map(copy(a:000), 'timl#printer#string(v:val)'), ' ')."\n"
TLexpr print_str(...) join(map(copy(a:000), 'timl#str(v:val)'), ' ')
TLexpr println_str(...) join(map(copy(a:000), 'timl#str(v:val)'), ' ')."\n"

TLexpr str(...) join(map(copy(a:000), 'timl#str(v:val)'), '')
TLexpr format(fmt, ...) call('printf', [timl#str(a:fmt)] + a:000)

TLfunction subs(str, start, ...)
  if a:0 && a:1 <= a:start
    return ''
  elseif a:0
    return matchstr(a:str, '.\{,'.(a:1-a:start).'\}', byteidx(a:str, a:start))
  else
    return a:str[byteidx(a:str, a:start) :]
  endif
endfunction

TLexpr join(sep_or_coll, ...)
      \ join(map(copy(a:0 ? a:1 : a:sep_or_coll), 'timl#str(v:val)'), a:0 ? a:sep_or_coll : '')
TLexpr split(s, re) split(a:s, '\C'.a:re)
TLexpr replace(s, re, repl)     substitute(a:s, '\C'.a:re, a:repl, 'g')
TLexpr replace_one(s, re, repl) substitute(a:s, '\C'.a:re, a:repl, '')
TLexpr re_quote_replacement(re) escape(a:re, '\~')
TLexpr re_find(re, s)           matchstr(a:s, '\C'.a:re)

" }}}1
" Section: Lists {{{1

TLalias list timl#list
TLalias list_STAR_ timl#list2
TLpredicate list_QMARK_(val) timl#consp(a:val)
TLalias cons timl#cons
TLalias conj timl#conj

" }}}1
" Section: Vectors {{{1

TLpredicate vector_QMARK_(val) timl#vectorp(a:val)
TLalias vector timl#persist
TLalias vec timl#vec

TLfunction! subvec(list, start, ...) abort
  if a:0 && a:1 == 0
    return type(a:list) == type('') ? '' : timl#persistentb([])
  elseif a:0
    return timl#persistentb(a:list[a:start : (a:1 < 0 ? a:1 : a:1-1)])
  else
    return timl#persistentb(a:list[a:start :])
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
    let dict[timl#str(list[i])] = list[i+1]
  endfor
  return timl#persistentb(dict)
endfunction

TLalias hash_map timl#hash_map
TLalias hash_set timl#hash_set
TLalias set timl#set
TLalias assoc timl#assoc
TLalias assoc_BANG_ timl#assocb
TLalias dissoc timl#dissoc
TLalias dissoc_BANG_ timl#dissocb

TLfunction! dict_QMARK_(val) abort
  return type(a:val) == type({}) ? s:true : s:false
endfunction

" }}}1
" Section: Collections {{{1

TLalias get timl#get

TLfunction! empty(coll) abort
  if timl#consp(a:coll)
    " TODO: empty list
    return g:timl#nil
  endif
  if type(a:coll) == type({}) && !timl#symbolp(a:coll)
    return {}
  elseif type(a:coll) == type('')
    return ''
  elseif type(a:coll) == type([])
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
    return timl#persistentb(result)
  endif
  let _ = {}
  let _.seq = timl#core#seq(a:coll)
  if empty(_.seq)
    return a:coll
  endif
  let tag = timl#intern_type('timl.lang/Cons')
  let head = {'#tag': tag,
        \ 'car': timl#call(a:f, [timl#core#first(_.seq)]),
        \ 'cdr': g:timl#nil}
  let ptr = head
  let _.seq = timl#core#next(_.seq)
  while _.seq isnot# g:timl#nil
    let ptr.cdr = {'#tag': tag,
          \ 'car': timl#call(a:f, [timl#core#first(_.seq)]),
          \ 'cdr': g:timl#nil}
    let ptr = timl#persistentb(ptr)
    let ptr = ptr.cdr
    let _.seq = timl#core#next(_.seq)
  endwhile
  lockvar 1 ptr
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

TLalias require timl#require
TLalias find_ns timl#find_ns
TLalias the_ns timl#the_ns

TLfunction! in_ns(ns) abort
  let name = timl#name(a:ns)
  let g:timl#core#_STAR_ns_STAR_ = timl#create_ns(name)
  return g:timl#core#_STAR_ns_STAR_
endfunction

TLfunction! refer(ns) abort
  let me = g:timl#core#_STAR_ns_STAR_.name
  call timl#create_ns(me, {'referring': [a:ns]})
  return g:timl#nil
endfunction

TLfunction! use(ns) abort
  call timl#require(a:ns)
  return g:timl#core#refer.call(a:ns)
endfunction

TLfunction! alias(alias, ns) abort
  let me = g:timl#core#_STAR_ns_STAR_.name
  call timl#create_ns(me, {'aliases': {timl#name(a:alias): a:ns}})
  return g:timl#nil
endfunction

" }}}1

delcommand TLfunction
delcommand TLalias
delcommand TLexpr
delcommand TLpredicate
unlet s:dict

call timl#source_file(expand('<sfile>:r') . '.macros.tim')
call timl#source_file(expand('<sfile>:r') . '.basics.tim')
call timl#source_file(expand('<sfile>:r') . '.seq.tim')
call timl#source_file(expand('<sfile>:r') . '.coll.tim')
call timl#source_file(expand('<sfile>:r') . '.vim.tim')

" vim:set et sw=2:
