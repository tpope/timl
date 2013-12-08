" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_reader")
  finish
endif
let g:autoloaded_timl_reader = 1

let s:iskeyword = '[[:alnum:]_=?!#$%&*+|./<>:-]'

function! s:read_token(port) abort
  let pat = '^\%(#"\%(\\\@<!\%(\\\\\)*\\"\|[^"]\)*"\|#[[:punct:]]\|"\%(\\.\|[^"]\)*"\|[[:space:],]\+\|;.\{-\}\ze\%(\n\|$\)\|\~@\|'.s:iskeyword.'\+\|\\\%(space\|tab\|newline\|return\|.\)\|.\)'
  let match = ' '
  while match =~# '^[[:space:],]'
    let [pos, line] = [a:port.pos, a:port.line]
    let match = matchstr(a:port.str, pat, a:port.pos)
    let a:port.pos += len(match)
    let a:port.line += len(substitute(match, "[^\n]", '', 'g'))
  endwhile
  return [match, pos, line]
endfunction

function! timl#reader#eofp(port)
  return a:port.pos >= len(a:port.str)
endfunction

let g:timl#reader#eof = []

function! timl#reader#read(port, ...) abort
  let error = 'timl#reader: EOF'
  try
    let val = s:read(a:port)
    if val isnot# g:timl#reader#eof
      return val
    elseif a:0
      return a:1
    endif
  catch /^timl.*/
    let error = v:exception
  endtry
  throw error
endfunction

function! s:read_until(port, char)
  let list = []
  let [token, pos, line] = s:read_token(a:port)
  while token !=# a:char && token !=# ''
    call add(list, s:read(a:port, token, pos, line))
    let [token, pos, line] = s:read_token(a:port)
  endwhile
  if token ==# a:char
    lockvar 1 list
    return list
  endif
  throw 'timl#reader: unexpected EOF on line ' . a:port.line
endfunction

let s:constants = {
      \ '\space': " ",
      \ '\tab': "\t",
      \ '\newline': "\n",
      \ '\return': "\r"}

function! s:add_meta(data, meta) abort
  let data = a:data
  if timl#symbolp(data)
    let data = copy(data)
  else
    unlockvar 1 data
  endif
  if has_key(data, '#meta')
    unlockvar 1 data['#meta']
  else
    let data['#meta'] = {'#tag': timl#intern_type('timl.lang/HashMap')}
  endif
  call extend(data['#meta'], a:meta)
  lockvar 1 data['#meta']
  lockvar 1 data
  return data
endfunction

function! s:read(port, ...) abort
  let port = a:port
  let [token, pos, line] = a:0 ? a:000 : s:read_token(a:port)
  let data = s:process(a:port, token, pos, line)
  if has_key(a:port, 'filename') && timl#consp(data)
    return s:add_meta(data, {'file': a:port.filename, 'line': line})
  endif
  return data
endfunction

function! s:process(port, token, pos, line) abort
  let port = a:port
  let pos = a:pos
  let token = a:token
  if token ==# '('
    return timl#list2(s:read_until(port, ')'))
  elseif token == '['
    return s:read_until(port, ']')
  elseif token == '{'
    let list = s:read_until(port, '}')
    if len(list) % 2 != 0
      let error = 'timl#reader: invalid hash map literal'
    else
      return timl#hash_map(list)
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
      lockvar 1 dict
      return dict
    endif
  elseif token == '#{'
    return timl#set(s:read_until(port, '}'))
  elseif has_key(s:constants, token)
    return s:constants[token]
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
  elseif token ==# '#('
    if has_key(port, 'argsyms')
      throw "timl#reader: can't nest #()"
    endif
    try
      let port.argsyms = {}
      let list = s:read_until(port, ')')
      let rest = has_key(port.argsyms, '%&')
      let args = map(range(1, len(port.argsyms) - rest), 'port.argsyms["%".v:val]')
      if rest
        call add(args, a:port.argsyms['%&'])
      endif
      return timl#list(timl#symbol('fn*'), args, timl#list2(list))
    finally
      unlet! a:port.argsyms
    endtry
  elseif token =~# '^%\d*$\|^%&$' && has_key(port, 'argsyms')
    let token = (token ==# '%' ? '%1' : token)
    if !has_key(port.argsyms, token)
      let port.argsyms[token] = timl#gensym('p1__')
    endif
    return port.argsyms[token]
  elseif token =~# '^#\a'
    let next = s:read(port)
    unlockvar 1 next
    let token = token[1:-1]
    if token !~# '[/.]'
      let token = 'timl.lang/'.token
    endif
    if type(next) == type({})
      return timl#persistentb(extend(next, {'#tag': timl#intern_type(token)}))
    else
      return timl#persistentb({'value': next, '#tag': timl#intern_type(token)})
    endif
  elseif token =~# '^:.'
    return timl#keyword(token[1:-1])
  elseif token =~# '^'.s:iskeyword
    return timl#symbol(token)
  elseif token ==# '^'
    let _meta = s:read(port)
    let data = s:read(port)
    if timl#keywordp(_meta)
      let meta = {_meta[0]: g:timl#true}
    elseif timl#symbolp(_meta)
      let meta = {'tag': _meta}
    else
      let meta = _meta
    endif
    if timl#objectp(data)
      return s:add_meta(data, meta)
    endif
    let error = 'timl#reader: cannot attach metadata to a '.timl#type(data)
  elseif token ==# '@'
    return timl#list(timl#symbol('timl.core/deref'), s:read_bang(port))
  elseif empty(token)
    return g:timl#reader#eof
  else
    let error = 'timl#reader: unexpected token '.string(token)
  endif
  throw error . ' on line ' . a:line
endfunction

function! s:read_bang(port) abort
  let val = s:read(a:port)
  if val isnot# g:timl#reader#eof
    return val
  endif
  throw 'timl#reader: unexpected EOF'
endfunction

function! timl#reader#open(filename) abort
  let str = join(readfile(a:filename), "\n")
  return {'str': str, 'filename': a:filename, 'pos': 0, 'line': 1}
endfunction

function! timl#reader#close(port)
  return a:port
endfunction

function! timl#reader#read_all(port) abort
  let all = []
  let _ = {}
  try
    while 1
      let _.form = s:read(a:port)
      if _.form is# g:timl#reader#eof
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
  return timl#reader#read_all({'str': a:str, 'pos': 0, 'line': 1})
endfunction

function! timl#reader#read_string(str) abort
  return timl#reader#read({'str': a:str, 'pos': 0, 'line': 1})
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
TimLRAssert timl#reader#read_string('{"a" 1 :b 2 3 "c"}') ==# {' "a"': 1, "b": 2, "3": "c", '#tag': timl#intern_type('timl.lang/HashMap')}
TimLRAssert timl#reader#read_string("[1]\n; hi\n") ==# [1]
TimLRAssert timl#reader#read_string("'[1 2 3]") ==# timl#list(timl#symbol('quote'), [1, 2, 3])
TimLRAssert timl#reader#read_string("`foo") ==# timl#list(timl#symbol('syntax-quote'), timl#symbol('foo'))
TimLRAssert timl#reader#read_string("~foo") ==# timl#list(timl#symbol('unquote'), timl#symbol('foo'))
TimLRAssert timl#reader#read_string("#*tr") ==# timl#list(timl#symbol('function'), timl#symbol('tr'))
TimLRAssert timl#reader#read_string("(1 #_2 3)") ==# timl#list(1, 3)
TimLRAssert timl#reader#read_string("^:foo {}") ==#
      \ {'#tag': timl#intern_type('timl.lang/HashMap'),
      \  '#meta': {'#tag': timl#intern_type('timl.lang/HashMap'), 'foo': g:timl#true}}


delcommand TimLRAssert

" }}}1

" vim:set et sw=2:
