" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_keyword")
  finish
endif
let g:autoloaded_timl_keyword = 1

if !exists('s:keywords')
  let s:keywords = {}
endif

function! timl#keyword#intern(str) abort
  if !has_key(s:keywords, a:str)
    let end = matchend(a:str, '^\%(&\=\w:\|\$\|&\%($\|form$\|env$\)\@!\|[^/]*/\).\@=')
    let keyword = timl#type#bless(s:type, {
          \ '0': a:str,
          \ 'str': a:str,
          \ 'namespace': end == -1 ? '' : a:str[0 : end-(a:str[end-1] ==# '/' ? 2 : 1)],
          \ 'name': end == -1 ? a:str : a:str[end : -1]})
    lockvar 1 keyword
    let s:keywords[a:str] = keyword
  endif
  return s:keywords[a:str]
endfunction

function! timl#keyword#test(keyword) abort
  return type(a:keyword) == type({}) && get(a:keyword, '__type__') is# s:type
endfunction

function! timl#keyword#cast(keyword) abort
  if timl#keyword#test(a:keyword)
    return a:keyword
  endif
  throw 'timl: keyword expected but received '.timl#type#string(a:keyword)
endfunction

function! timl#keyword#to_string(this) abort
  return a:this.str
endfunction

function! timl#keyword#name(this) abort
  return a:this.name
endfunction

function! timl#keyword#namespace(this) abort
  return a:this.namespace
endfunction

function! timl#keyword#call(this, _) abort
  if len(a:_) < 1 || len(a:_) > 2
    throw 'timl: arity error'
  endif
  return call('timl#coll#get', [a:_[0], a:this] + a:_[1:-1])
endfunction

let s:type = timl#type#core_create('Keyword')
