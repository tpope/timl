" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_reader")
  finish
endif
let g:autoloaded_timl_reader = 1

let s:iskeyword = '[[:alnum:]_=?!#$%&*+|./<>:~-]'

function! s:tokenize(str) abort
  let tokens = []
  let i = 0
  let len = len(a:str)
  while i < len
    let chs = matchstr(a:str, '..\=', i)
    let ch = matchstr(chs, '.')
    if ch =~# s:iskeyword
      let token = matchstr(a:str, s:iskeyword.'*', i)
      let i += strlen(token)
      call add(tokens, token)
    elseif ch ==# '"'
      let token = matchstr(a:str, '"\%(\\.\|[^"]\)*"', i)
      let i += strlen(token)
      call add(tokens, token)
    elseif ch =~# "[[:space:]\r\n]"
      let i = matchend(a:str, "[[:space:]\r\n]*", i)
    elseif ch ==# ';'
      let token = matchstr(a:str, ';.\{-\}\ze\%(\n\|$\)', i)
      let i += strlen(token)
      " call add(tokens, token)
    elseif chs ==# ',@'
      call add(tokens, chs)
      let i += len(chs)
    else
      call add(tokens, ch)
      let i += len(ch)
    endif
  endwhile
  return tokens
endfunction

function! s:read_one(tokens, i) abort
  let error = 'timl.vim: unexpected EOF'
  let i = a:i
  while i < len(a:tokens)
    if a:tokens[i] =~# '^"\|^[+-]\=\d\%(.*\d\)\=$'
      return [eval(a:tokens[i]), i+1]
    elseif a:tokens[i] ==# '('
      let i += 1
      let list = []
      while i < len(a:tokens) && a:tokens[i] !=# ')'
        let [val, i] = s:read_one(a:tokens, i)
        call add(list, val)
        unlet! val
      endwhile
      if i >= len(a:tokens)
        break
      endif
      return [list, i+1]
    elseif a:tokens[i] ==# '{'
      let i += 1
      let dict = {}
      while i < len(a:tokens) && a:tokens[i] !=# '}'
        let [key, i] = s:read_one(a:tokens, i)
        if type(key) != type('')
          let error = 'timl.vim: dict keys must be strings'
        elseif a:tokens[i] ==# '}'
          let error = 'timl.vim: dict literal contains odd number of elements'
        endif
        let [val, i] = s:read_one(a:tokens, i)
        let dict[key] = val
        unlet! key val
      endwhile
      if i >= len(a:tokens)
        break
      endif
      return [dict, i+1]
    elseif a:tokens[i] ==# 'nil'
      return [g:timl#nil, i+1]
    elseif a:tokens[i] ==# "'"
      let [val, i] = s:read_one(a:tokens, i+1)
      return [[timl#symbol('quote'), val], i]
    elseif a:tokens[i] ==# '`'
      let [val, i] = s:read_one(a:tokens, i+1)
      return [[timl#symbol('quasiquote'), val], i]
    elseif a:tokens[i] ==# ','
      let [val, i] = s:read_one(a:tokens, i+1)
      return [[timl#symbol('unquote'), val], i]
    elseif a:tokens[i] ==# ',@'
      let [val, i] = s:read_one(a:tokens, i+1)
      return [[timl#symbol('unquote-splicing'), val], i]
    elseif a:tokens[i][0] ==# ';'
      let i += 1
      continue
    elseif a:tokens[i] =~# '^'.s:iskeyword
      return [timl#symbol(a:tokens[i]), i+1]
    else
      let error = 'timl.vim: unexpected token: '.string(a:tokens[i])
      break
    endif
  endwhile
  throw error
endfunction

function! timl#reader#read_string_all(str) abort
  let tokens = s:tokenize(a:str)
  let forms = []
  let i = 0
  while i < len(tokens)
    let [form, i] = s:read_one(tokens, i)
    call add(forms, form)
  endwhile
  return forms
endfunction

function! timl#reader#read_string(str) abort
  return s:read_one(s:tokenize(a:str), 0)[0]
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
      \ if !eval(<q-args>) | echomsg "Failed: ".<q-args> |
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

delcommand TimLRAssert

" }}}1

" vim:set et sw=2:
