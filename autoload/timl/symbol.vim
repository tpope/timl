" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_symbol")
  finish
endif
let g:autoloaded_timl_symbol = 1

if !exists('s:symbols')
  let s:symbols = {}
endif

function! timl#symbol#intern(str) abort
  if !has_key(s:symbols, a:str)
    let end = matchend(a:str, '^\%(&\=\w:\|\$\|&\%($\|form$\|env$\)\@!\|[^/]*/\).\@=')
    let symbol = timl#type#bless(s:type, {
          \ '0': a:str,
          \ 'str': a:str,
          \ 'meta': g:timl#nil,
          \ 'namespace': end == -1 ? '' : a:str[0 : end-(a:str[end-1] ==# '/' ? 2 : 1)],
          \ 'name': end == -1 ? a:str : a:str[end : -1]})
    lockvar 1 symbol
    let s:symbols[a:str] = symbol
  endif
  return s:symbols[a:str]
endfunction

function! timl#symbol#intern_with_meta(str, meta) abort
  let sym = copy(timl#symbol#intern(a:str))
  let sym.meta = a:meta
  return sym
endfunction

function! timl#symbol#test(symbol)
  return type(a:symbol) == type({}) &&
        \ get(a:symbol, '__tag__') is# s:type.blessing
endfunction

function! timl#symbol#is(symbol, ...)
  return type(a:symbol) == type({}) &&
        \ get(a:symbol, '__tag__') is# s:type.blessing &&
        \ (a:0 ? a:symbol[0] ==# a:1 : 1)
endfunction

function! timl#symbol#cast(symbol)
  if !timl#symbol#test(a:symbol)
    throw 'timl: symbol expected but received '.timl#type#string(a:symbol)
  endif
  return a:symbol
endfunction

function! timl#symbol#equal(this, that)
  return timl#symbol#test(a:that) && a:this[0] ==# a:that[0] ? g:timl#true : g:timl#false
endfunction

function! timl#symbol#gen(...)
  let s:id = get(s:, 'id', 0) + 1
  return timl#symbol((a:0 ? a:1 : 'G__').s:id)
endfunction

let s:type = timl#type#core_create('Symbol')
