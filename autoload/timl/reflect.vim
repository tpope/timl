if exists("g:autoloaded_timl_reflect") || &cp || v:version < 700
  finish
endif
let g:autoloaded_timl_reflect = 1

function! timl#reflect#ns_uses(ns) abort
  return timl#namespace#the(a:ns).referring
endfunction

function! timl#reflect#vars_matching(pattern) abort
  return filter(copy(g:), 'v:key =~# a:pattern')
endfunction

function! timl#reflect#ns_var_completion(ns) abort
  let nses = [a:ns] + timl#reflect#ns_uses(a:ns)
  let fns = timl#reflect#vars_matching('^\%('.join(map(copy(nses),'timl#munge(timl#str(v:val))'),'\|').'\)#')
  let locals = {}
  let _ = {}
  for [fn, _.var] in items(fns)
    if type(_.var) == type({})
      let locals[timl#demunge(matchstr(fn, '.*#\zs.*'))] = get(_.var, 'arglist', g:timl#nil)
    endif
  endfor
  return locals
endfunction

function! timl#reflect#omnicomplete(findstart, base) abort
  if a:findstart
    let line = getline('.')[0 : col('.')-2]
    return col('.') - strlen(matchstr(line, '\k\+$')) - 1
  endif
  let results = []
  let ns = timl#ns_for_file(expand('%'))
  if timl#namespace#find(ns) is g:timl#nil
    let ns = 'user'
  endif
  let found = timl#reflect#ns_var_completion(ns)
  for fn in sort(keys(found))
    call add(results, {'word': fn, 'menu': '(' . join(map(copy(found[fn]), 'timl#str(v:val)'), ' ') . ')'})
  endfor
  return filter(results, 'a:base ==# "" || a:base ==# v:val.word[0 : strlen(a:base)-1]')
endfunction

function! timl#reflect#input_complete(A, L, P) abort
  let prefix = matchstr(a:A, '\%(.* \|^\)\%(#\=[\[{('']\)*')
  let keyword = a:A[strlen(prefix) : -1]
  return sort(map(timl#reflect#omnicomplete(0, keyword), 'prefix . v:val.word'))
endfunction
