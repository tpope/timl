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
    let s:keywords[a:str] = {'0': a:str, '__call__': function('timl#keyword#apply')}
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

function! timl#keyword#call(this, _) abort
  if len(a:_) < 1 || len(a:_) > 2
    throw 'timl: arity error'
  endif
  return call('timl#coll#get', [a:_[0], a:this] + a:_[1:-1])
endfunction

function! timl#keyword#apply(_) dict abort
  return timl#keyword#call(self, a:_)
endfunction
