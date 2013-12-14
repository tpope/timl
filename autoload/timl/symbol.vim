" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_symbol")
  finish
endif
let g:autoloaded_timl_symbol = 1

if !exists('s:symbols')
  let s:symbols = {}
endif

let s:symbol = timl#keyword('#timl.lang/Symbol')
function! timl#symbol#intern(str)
  if !has_key(s:symbols, a:str)
    let s:symbols[a:str] = timl#bless(s:symbol, {'0': a:str})
    lockvar s:symbols[a:str]
  endif
  return s:symbols[a:str]
endfunction

function! timl#symbol#test(symbol)
  return type(a:symbol) == type({}) &&
        \ get(a:symbol, '#tag') is# s:symbol
endfunction

function! timl#symbol#is(symbol, ...)
  return type(a:symbol) == type({}) &&
        \ get(a:symbol, '#tag') is# s:symbol &&
        \ (a:0 ? a:symbol[0] ==# a:1 : 1)
endfunction

function! timl#symbol#coerce(symbol)
  if !timl#symbol#test(a:symbol)
    throw 'timl: symbol expected but received '.timl#type#string(a:symbol)
  endif
  return a:symbol
endfunction

function! timl#symbol#gen(...)
  let s:id = get(s:, 'id', 0) + 1
  return timl#symbol((a:0 ? a:1 : 'G__').s:id)
endfunction
