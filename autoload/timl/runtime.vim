if exists("g:autoloaded_timl_runtime") || &cp || v:version < 700
  finish
endif
let g:autoloaded_timl_runtime = 1

" Section: Misc {{{1

function! timl#runtime#nil_QMARK_(val) abort
  return empty(a:val)
endfunction

function! timl#runtime#symbol_QMARK_(symbol) abort
  return timl#symbol_p(a:symbol)
endfunction

function! timl#runtime#symbol(str) abort
  return timl#symbol(a:str)
endfunction

function! timl#runtime#string(...) abort
  let acc = ''
  let _ = {}
  for _.x in a:000
    if timl#symbol_p(_.x)
      let acc .= _.x[0]
    elseif type(_.x) == type('')
      let acc .= _.x
    elseif type(_.x) == type(function('tr'))
      return join([_.x])
    else
      let acc .= string(_.x)
    endif
  endfor
  return acc
endfunction

function! timl#runtime#identity(x) abort
  return a:x
endfunction

" }}}1
" Section: Operators {{{

function! timl#runtime#_PLUS_(...) abort
  let acc = 0
  for elem in a:000
    let acc += elem
  endfor
  return acc
endfunction

function! timl#runtime#_STAR_(...) abort
  let acc = 1
  for elem in a:000
    let acc = acc * elem
  endfor
  return acc
endfunction

function! timl#runtime#_(x, ...) abort
  if a:0
    let acc = a:x
    for elem in a:000
      let acc -= elem
    endfor
    return acc
  else
    return -a:x
  endif
endfunction

function! timl#runtime#_SLASH_(x, ...) abort
  if a:0
    let acc = a:x
    for elem in a:000
      let acc = acc / elem
    endfor
    return acc
  else
    return 1 / a:x
  endif
endfunction

function! timl#runtime#_PERCENT_(x, y) abort
  return a:x % a:y
endfunction

function! timl#runtime#_GT_(x, y) abort
  return a:x ># a:y
endfunction

function! timl#runtime#_LT_(x, y) abort
  return a:x <# a:y
endfunction

function! timl#runtime#_GT__EQ_(x, y) abort
  return a:x >=# a:y
endfunction

function! timl#runtime#_LT__EQ_(x, y) abort
  return a:x <=# a:y
endfunction

function! timl#runtime#_EQ__TILDE_(x, y) abort
  return type(a:x) == type('') && type(a:y) == type('') && a:x =~# a:y
endfunction

function! timl#runtime#_EQ__TILDE__QMARK_(x, y) abort
  return type(a:x) == type('') && type(a:y) == type('') && a:x =~? a:y
endfunction

function! timl#runtime#_EQ_(x, y) abort
  return type(a:x) == type(a:y) && a:x ==# a:y
endfunction

function! timl#runtime#eq_QMARK_(x, y) abort
  return a:x is# a:y
endfunction

" }}}1
" Section: Lists {{{1

function! timl#runtime#length(list) abort
  return len(a:list)
endfunction

function! timl#runtime#first(list) abort
  return get(a:list, 0, g:timl#nil)
endfunction

function! timl#runtime#rest(list) abort
  return a:list[1:-1]
endfunction

function! timl#runtime#car(list) abort
  return get(a:list, 0, g:timl#nil)
endfunction

function! timl#runtime#cdr(list) abort
  return a:list[1:-1]
endfunction

function! timl#runtime#list(...) abort
  return a:000
endfunction

function! timl#runtime#get(coll, key, ...) abort
  if type(a:coll) == type([]) && type(a:key) != type(0)
    return g:timl#nil
  endif
  return get(a:coll, a:key, a:0 ? a:1 : g:timl#nil)
endfunction

function! timl#runtime#sublist(list, start, ...) abort
  if a:0
    return a:list[a:start : a:1]
  else
    return a:list[a:start :]
  endif
endfunction

function! timl#runtime#list_QMARK_(val) abort
  return !timl#symbol_p(a:val) && type(a:val) == type([])
endfunction

function! timl#runtime#dict(...) abort
  let list = copy(a:000)
  while len(a:000) % 2 !=# 0 && timl#runtime#list_QMARK_(list[-1])
    call extend(list, remove(list, -1))
  endwhile
  if len(list) % 2 !=# 0
    throw 'timl.vim: dict requires a even number of arguments'
  endif
  let dict = {}
  for i in range(0, len(list)-1, 2)
    let dict[list[i]] = list[i+1]
  endfor
  return dict
endfunction

function! timl#runtime#dict_QMARK_(val) abort
  return type(a:val) == type({})
endfunction

function! timl#runtime#append(...) abort
  let acc = []
  for elem in a:000
    call extend(acc, elem)
  endfor
  return acc
endfunction

function! timl#runtime#cons(val, list) abort
  return [a:val] + a:list
endfunction

function! timl#runtime#map(f, list) abort
  return map(copy(a:list), 'call(a:f, [v:val], {})')
endfunction

function! timl#runtime#filter(f, list) abort
  return filter(copy(a:list), 'call(a:f, [v:val], {})')
endfunction

function! timl#runtime#reduce(f, val_or_list, ...) abort
  let _ = {}
  if a:0
    let _.val = a:val_or_list
    let list = a:1
  elseif empty(a:val_or_list)
    return g:timl#nil
  else
    let list = copy(a:val_or_list)
    let _.val = remove(list, 0)
  endif
  for _.elem in list
    let _.val = call(a:f, [_.val, _.elem], {})
  endfor
  return _.val
endfunction

" }}}1

" vim:set et sw=2:
