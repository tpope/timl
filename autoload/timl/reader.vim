" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_reader")
  finish
endif
let g:autoloaded_timl_reader = 1

let s:iskeyword = '[[:alnum:]_=?!#$%&*+|./<>:~-]'

let g:timl#reader#tag_handlers = {}

function g:timl#reader#tag_handlers.dict(list)
  let list = timl#cons#to_vector(a:list)
  if len(list) % 2 == 0
    let dict = {}
    for i in range(0, len(list)-1, 2)
      let dict[type(list[i]) == type([]) ? substitute(join(list[i]), '^:', '', '') : list[i]] = list[i+1]
    endfor
    return dict
  endif
  throw 'timl#reader: invalid dict literal'
endfunction

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
  let error = 'timl#reader: EOF'
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

function! s:read_until(port, char)
  let list = []
  let token = s:read_token(a:port)
  while token !=# a:char && token !=# ''
    call add(list, s:read(a:port, token, a:port.pos))
    let token = s:read_token(a:port)
  endwhile
  if token ==# a:char
    return list
  endif
  throw 'timl#reader: unexpected EOF at byte ' . a:port.pos
endfunction

function! s:read(port, ...) abort
  let port = a:port
  let pos = a:0 ? a:2 : port.pos
  let token = a:0 ? a:1 : s:read_token(port)
  if token ==# '('
    return s:read_until(port, ')')
  elseif token == '{'
    let list = s:read_until(port, '}')
    if type(list) !=# type([]) || len(list) % 2 != 0
      let error = 'timl#reader: invalid dict literal'
    else
      let dict = {}
      for i in range(0, len(list)-1, 2)
        if timl#symbolp(list[i])
          if list[i][0][0] ==# ':'
            let key = list[i][0][1:-1]
          else
            let key = "'".list[i][0]
          endif
        elseif type(list[i]) == type(0)
          let key = ';' . list[i]
        elseif type(list[i]) == type("")
          let key = '"' . list[i]
        else
      let error = 'timl#reader: invalid dict key type'
        endif
        let dict[key] = list[i+1]
      endfor
      return dict
    endif
  elseif token ==# 'nil'
    return g:timl#nil
  elseif token ==# 'false'
    return g:timl#false
  elseif token ==# 'true'
    return g:timl#true
  elseif token =~# '^\d\+e\d\+$'
    return eval(substitute(token, 'e', '.0e', ''))
  elseif token =~# '^\.\d'
    return eval('0'.token)
  elseif token =~# '^"\|^[+-]\=\d\%(.*\d\)\=$'
    return eval(token)
  elseif token ==# "'"
    return [timl#symbol('quote'), s:read_bang(port)]
  elseif token ==# '`'
    return [timl#symbol('quasiquote'), s:read_bang(port)]
  elseif token ==# ','
    return [timl#symbol('unquote'), s:read_bang(port)]
  elseif token ==# ',@'
    return [timl#symbol('unquote-splicing'), s:read_bang(port)]
  elseif token ==# '#'''
    return [timl#symbol('function'), s:read_bang(port)]
  elseif token[0] ==# ';'
    return s:read(port)
  elseif token ==# '#_'
    call s:read(port)
    return s:read(port)
  elseif token =~# '^#\a'
    let next = s:read(port)
    if has_key(g:timl#reader#tag_handlers, token[1:-1])
      return g:timl#reader#tag_handlers[token[1:-1]](next)
    elseif type(next) == type([])
      return insert(next, timl#symbol(token))
    elseif type(next) == type({})
      return extend(next, {'#tag': timl#symbol(token)})
    else
      return {'value': next, '#tag': timl#symbol(token)}
    endif
  elseif token =~# '^'.s:iskeyword || token =~# '^@.$'
    return timl#symbol(token)
  elseif empty(token)
    return s:eof
  else
    let error = 'timl#reader: unexpected token '.string(token)
  endif
  throw error . ' at byte ' . pos
endfunction

function! s:read_bang(port) abort
  let val = s:read(a:port)
  if val isnot# s:eof
    return val
  endif
  throw 'timl#reader: unexpected EOF'
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
TimLRAssert timl#reader#read_string('#dict("a" 1 "b" 2)') ==# {"a": 1, "b": 2}
TimLRAssert timl#reader#read_string('{"a" 1 :b 2 3 "c"}') ==# {'"a': 1, "b": 2, ";3": "c"}
TimLRAssert timl#reader#read_string("(1)\n; hi\n") ==# [1]
TimLRAssert timl#reader#read_string('({})') ==# [{}]
TimLRAssert timl#reader#read_string("'(1 2 3)") ==# [timl#symbol('quote'), [1, 2, 3]]
TimLRAssert timl#reader#read_string("`foo") ==# [timl#symbol('quasiquote'), timl#symbol('foo')]
TimLRAssert timl#reader#read_string(",foo") ==# [timl#symbol('unquote'), timl#symbol('foo')]
TimLRAssert timl#reader#read_string("#'tr") ==# [timl#symbol('function'), timl#symbol('tr')]
TimLRAssert timl#reader#read_string("(1 #_2 3)") ==# [1, 3]

delcommand TimLRAssert

" }}}1

" vim:set et sw=2:
