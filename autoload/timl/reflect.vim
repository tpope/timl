if exists("g:autoloaded_timl_reflect") || &cp || v:version < 700
  finish
endif
let g:autoloaded_timl_reflect = 1

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
  let results = map(keys(timl#namespace#find(ns).mappings), '{"word": v:val}')
  return filter(results, 'v:val.word[0] !=# "#" && (a:base ==# "" || a:base ==# v:val.word[0 : strlen(a:base)-1])')
endfunction

function! timl#reflect#input_complete(A, L, P) abort
  let prefix = matchstr(a:A, '\%(.* \|^\)\%(#\=[\[{('']\)*')
  let keyword = a:A[strlen(prefix) : -1]
  return sort(map(timl#reflect#omnicomplete(0, keyword), 'prefix . v:val.word'))
endfunction
