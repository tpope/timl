" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_keyword")
  finish
endif
let g:autoloaded_timl_keyword = 1

if !exists('s:keywords')
  let s:keywords = {}
endif

function! timl#keyword#intern(str)
  if !has_key(s:keywords, a:str)
    let s:keywords[a:str] = {'0': a:str}
    lockvar s:keywords[a:str]
  endif
  return s:keywords[a:str]
endfunction

function! timl#keyword#test(keyword)
  return type(a:keyword) == type({}) &&
        \ has_key(a:keyword, 0) &&
        \ type(a:keyword[0]) == type('') &&
        \ get(s:keywords, a:keyword[0], 0) is a:keyword
endfunction

function! timl#keyword#cast(keyword)
  if !timl#keyword#test(a:keyword)
    throw 'timl: keyword expected but received '.timl#type#string(a:keyword)
  endif
  return a:keyword
endfunction
