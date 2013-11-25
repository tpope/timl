if exists("g:autoloaded_timl_reflect") || &cp || v:version < 700
  finish
endif
let g:autoloaded_timl_reflect = 1

function! timl#reflect#ns_uses(ns) abort
  return get(g:, timl#munge(a:ns.'#*uses*'), [timl#symbol('timl#core')])
endfunction

function! timl#reflect#functions_matching(pattern) abort
  redir => str
  silent execute 'function! /'.a:pattern
  redir END
  let fns = {}
  for line in split(str, "\n")
    let fn = matchstr(line, ' \zs.*\ze(')
    let sig = matchstr(line, '(\zs.*\ze)')
    if len(fn)
      let fns[timl#demunge(fn)] = map(split(sig, ', '), 'timl#demunge(v:val)')
    endif
  endfor
  return fns
endfunction

function! timl#reflect#ns_function_completion(ns) abort
  let nses = [a:ns] + timl#reflect#ns_uses(a:ns)
  let fns = timl#reflect#functions_matching('^\%('.join(map(copy(nses),'timl#munge(v:val)'),'\|').'\)#')
  let locals = {}
  for [fn, sig] in items(fns)
    let locals[matchstr(fn, '.*#\zs.*')] = sig
  endfor
  return locals
endfunction

function! timl#reflect#omnicomplete(findstart, base) abort
  if a:findstart
    let line = getline('.')[0 : col('.')-2]
    return col('.') - strlen(matchstr(line, '\k\+$')) - 1
  endif
  let results = []
  let found = timl#reflect#ns_function_completion(timl#ns_for_file(expand('%')))
  for fn in sort(keys(found))
    call add(results, {'word': fn, 'menu': '(' . join(found[fn], ' ') . ')'})
  endfor
  return filter(results, 'a:base ==# "" || a:base ==# v:val.word[0 : strlen(a:base)-1]')
endfunction

function! timl#reflect#input_complete(A, L, P) abort
  let prefix = matchstr(a:A, '\%(.* \|^\)\%(#\=[\[{('']\)*')
  let keyword = a:A[strlen(prefix) : -1]
  return sort(map(timl#reflect#omnicomplete(0, keyword), 'prefix . v:val.word'))
endfunction
