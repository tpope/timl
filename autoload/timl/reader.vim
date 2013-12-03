" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_reader")
  finish
endif
let g:autoloaded_timl_reader = 1

let s:iskeyword = '[[:alnum:]_=?!#$%&*+|./<>:-]'

let g:timl#reader#tag_handlers = {}

function! s:read_token(port) abort
  let pat = '^\%(#"\%(\\\@<!\%(\\\\\)*\\"\|[^"]\)*"\|#[[:punct:]]\|"\%(\\.\|[^"]\)*"\|[[:space:],]\|;.\{-\}\ze\%(\n\|$\)\|\~@\|'.s:iskeyword.'\+\|@.\|\\\%(space\|tab\|newline\|return\|.\)\|.\)'
  let match = matchstr(a:port.str, pat, a:port.pos)
  let a:port.pos += len(match)
  while match =~# '^[[:space:],]'
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
    lockvar list
    return list
  endif
  throw 'timl#reader: unexpected EOF at byte ' . a:port.pos
endfunction

let s:constants = {
      \ 'nil': g:timl#nil,
      \ 'false': g:timl#false,
      \ 'true': g:timl#true,
      \ '\space': " ",
      \ '\tab': "\t",
      \ '\newline': "\n",
      \ '\return': "\r"}

function! s:read(port, ...) abort
  let port = a:port
  let pos = a:0 ? a:2 : port.pos
  let token = a:0 ? a:1 : s:read_token(port)
  if token ==# '('
    return timl#list2(s:read_until(port, ')'))
  elseif token == '['
    return s:read_until(port, ']')
  elseif token == '{'
    let list = s:read_until(port, '}')
    if len(list) % 2 != 0
      let error = 'timl#reader: invalid dict literal'
    else
      let dict = {'#tag': timl#symbol('#timl#lang#HashMap')}
      for i in range(0, len(list)-1, 2)
        let key = timl#key(list[i])
        let dict[key] = list[i+1]
      endfor
      lockvar dict
      return dict
    endif
  elseif token == '#['
    let list = s:read_until(port, ']')
    if len(list) % 2 != 0
      let error = 'timl#reader: invalid dict literal'
    else
      let dict = {}
      for i in range(0, len(list)-1, 2)
        if type(list[i]) !=# type("")
          let error = 'timl#reader: dict keys must be strings'
          break
        endif
        let dict[list[i]] = list[i+1]
      endfor
    endif
    if !exists('error')
      lockvar dict
      return dict
    endif
  elseif token == '#{'
    let list = s:read_until(port, '}')
    let dict = {'#tag': timl#symbol('#timl#lang#HashSet')}
    let _ = {}
    for _.key in list
      let dict[timl#key(_.key)] = _.key
    endfor
    lockvar dict
    return dict
  elseif has_key(s:constants, token)
    return s:constants[token]
  elseif token =~# '^\d\+e\d\+$'
    return eval(substitute(token, 'e', '.0e', ''))
  elseif token =~# '^\.\d'
    return eval('0'.token)
  elseif token =~# '^"\|^[+-]\=\d\%(.*\d\)\=$'
    return eval(token)
  elseif token =~# '^#"'
    return substitute(token[2:-2], '\\\@<!\(\%(\\\\\)*\)\\"', '\1"', 'g')
  elseif token[0] ==# '\'
    return token[1]
  elseif token ==# "'"
    return timl#list(timl#symbol('quote'), s:read_bang(port))
  elseif token ==# '`'
    return timl#list(timl#symbol('syntax-quote'), s:read_bang(port))
  elseif token ==# '~'
    return timl#list(timl#symbol('unquote'), s:read_bang(port))
  elseif token ==# '~@'
    return timl#list(timl#symbol('unquote-splicing'), s:read_bang(port))
  elseif token ==# '#*'
    return timl#list(timl#symbol('function'), s:read_bang(port))
  elseif token[0] ==# ';'
    return s:read(port)
  elseif token ==# '#_'
    call s:read(port)
    return s:read(port)
  elseif token =~# '^#\a'
    let next = s:read(port)
    unlockvar next
    if token =~# '\.'
      let token = tr(token, '.', '#')
    else
      let token = '#timl#lang'.token
    endif
    call timl#autoload(token[1:-1])
    if has_key(g:timl#reader#tag_handlers, token[1:-1])
      return g:timl#reader#tag_handlers[token[1:-1]](next)
    elseif type(next) == type([]) && !timl#symbolp(next)
      return timl#lock(insert(next, timl#symbol(token)))
    elseif type(next) == type({})
      return timl#lock(extend(next, {'#tag': timl#symbol(token)}))
    else
      return timl#lock({'value': next, '#tag': timl#symbol(token)})
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

if !$TIML_TEST
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
TimLRAssert timl#reader#read_string('#"\(a\\\)"') ==# '\(a\\\)'
TimLRAssert timl#reader#read_string('#"\""') ==# '"'
TimLRAssert timl#reader#read_string('(first [1 2])') ==# timl#list(timl#symbol('first'), [1, 2])
TimLRAssert timl#reader#read_string('#["a" 1 "b" 2]') ==# {"a": 1, "b": 2}
TimLRAssert timl#reader#read_string('{"a" 1 :b 2 3 "c"}') ==# {' "a"': 1, "b": 2, "3": "c", '#tag': timl#symbol('#timl#lang#HashMap')}
TimLRAssert timl#reader#read_string("[1]\n; hi\n") ==# [1]
TimLRAssert timl#reader#read_string("'[1 2 3]") ==# timl#list(timl#symbol('quote'), [1, 2, 3])
TimLRAssert timl#reader#read_string("`foo") ==# timl#list(timl#symbol('syntax-quote'), timl#symbol('foo'))
TimLRAssert timl#reader#read_string("~foo") ==# timl#list(timl#symbol('unquote'), timl#symbol('foo'))
TimLRAssert timl#reader#read_string("#*tr") ==# timl#list(timl#symbol('function'), timl#symbol('tr'))
TimLRAssert timl#reader#read_string("(1 #_2 3)") ==# timl#list(1, 3)


delcommand TimLRAssert

" }}}1

" vim:set et sw=2:
