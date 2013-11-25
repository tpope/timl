" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_reader")
  finish
endif
let g:autoloaded_timl_reader = 1

let s:iskeyword = '[[:alnum:]_=?!#$%&*+|./<>:~-]'

function! s:read_token(port) abort
  let pat = '^\%(#[[:punct:]]\|"\%(\\.\|[^"]\)*"\|[[:space:]]\|;.\{-\}\ze\%(\n\|$\)\|,@\|'.s:iskeyword.'\+\|@.\|.\)'
  let match = matchstr(a:port.str, pat, a:port.pos)
  let a:port.pos += len(match)
  while match =~# '^[[:space:]]'
    let match = matchstr(a:port.str, pat, a:port.pos)
    let a:port.pos += len(match)
  endwhile
  return match
endfunction

function! s:tokenize(str) abort
  let tokens = []
  let port = {'pos': 0, 'str': a:str}
  let token = s:read_token(port)
  while !empty(token)
    call add(tokens, token)
    let token = s:read_token(port)
  endwhile
  return tokens
endfunction

function! s:eof(port)
  return a:port.pos >= len(a:port.str)
endfunction

let s:eof = []

function! timl#reader#read(port) abort
  let error = 'timl.vim: EOF'
  try
    let val = s:read(a:port)
    if val isnot# s:eof
      return val
    endif
  catch /^timl.*/
    let error = v:exception
  endtry
  throw error
endfunction

function! s:read(port, ...) abort
  let error = 'timl.vim: unexpected EOF'
  let port = a:port
  let pos = a:0 ? a:2 : port.pos
  let token = a:0 ? a:1 : s:read_token(port)
  if token =~# '^"\|^[+-]\=\d\%(.*\d\)\=$'
    return eval(token)
  elseif token ==# '('
    let list = []
    let token = s:read_token(port)
    while token !=# ')' && token !=# ''
      call add(list, s:read(port, token, pos))
      let token = s:read_token(port)
    endwhile
    if token ==# ')'
      return list
    endif
  elseif token ==# '{'
    let dict = {}
    let token = s:read_token(port)
    while 1
      if token ==# '}'
        return dict
      elseif token ==# ''
        break
      endif
      let key = s:read(port, token, pos)
      if type(key) != type('')
        let error = 'timl.vim: dict keys must be strings'
        break
      endif
      let dict[key] = s:read_bang(port)
      let token = s:read_token(port)
    endwhile
  elseif token ==# 'nil'
    return g:timl#nil
  elseif token ==# "'"
    return [timl#symbol('quote'), s:read_bang(port)]
  elseif token ==# '`'
    return [timl#symbol('quasiquote'), s:read_bang(port)]
  elseif token ==# ','
    return [timl#symbol('unquote'), s:read_bang(port)]
  elseif token ==# ',@'
    return [timl#symbol('unquote-splicing'), s:read_bang(port)]
  elseif token[0] ==# ';'
    return s:read(port)
  elseif token ==# '#_'
    call s:read(port)
    return s:read(port)
  elseif token =~# '^'.s:iskeyword || token =~# '^@.$'
    return timl#symbol(token)
  elseif empty(token)
    return s:eof
  else
    let error = 'timl.vim: unexpected token '.string(token)
  endif
  throw error . ' at byte ' . port.pos
endfunction

function! s:read_bang(port) abort
  let val = s:read(a:port)
  if val isnot# s:eof
    return val
  endif
  throw 'timl.vim: unexpected EOF'
endfunction

function! timl#reader#read_all(port) abort
  let all = []
  let _ = {}
  try
    while 1
      let _.form = s:read(a:port)
      if _.form is# s:eof
        return all
      endif
      call add(all, _.form)
    endwhile
  catch /^timl.*/
    let error = v:exception
  endtry
  throw error
endfunction

function! timl#reader#read_string_all(str) abort
  return timl#reader#read_all({'str': a:str, 'pos': 0})
endfunction

function! timl#reader#read_string(str) abort
  return timl#reader#read({'str': a:str, 'pos': 0})
endfunction

function! timl#reader#read_file(filename) abort
  return timl#reader#read_string_all(join(readfile(a:filename), "\n"))
endfunction

" Section: Tests {{{1

if !exists('$TEST')
  finish
endif

command! -nargs=1 TimLRAssert
      \ try |
      \ if !eval(<q-args>) |
      \ echomsg "Failed: ".<q-args> |
      \   endif |
      \ catch /.*/ |
      \  echomsg "Error:  ".<q-args>." (".v:exception.")" |
      \ endtry

TimLRAssert timl#reader#read_string('foo') ==# timl#symbol('foo')
TimLRAssert timl#reader#read_string('":)"') ==# ':)'
TimLRAssert timl#reader#read_string('(car (list 1 2))') ==# [timl#symbol('car'), [timl#symbol('list'), 1, 2]]
TimLRAssert timl#reader#read_string('{"a" 1 "b" 2}') ==# {"a": 1, "b": 2}
TimLRAssert timl#reader#read_string("(1)\n; hi\n") ==# [1]
TimLRAssert timl#reader#read_string('({})') ==# [{}]
TimLRAssert timl#reader#read_string("'(1 2 3)") ==# [timl#symbol('quote'), [1, 2, 3]]
TimLRAssert timl#reader#read_string("`foo") ==# [timl#symbol('quasiquote'), timl#symbol('foo')]
TimLRAssert timl#reader#read_string(",foo") ==# [timl#symbol('unquote'), timl#symbol('foo')]
TimLRAssert timl#reader#read_string("(1 #_2 3)") ==# [1, 3]

delcommand TimLRAssert

" }}}1

" vim:set et sw=2:
