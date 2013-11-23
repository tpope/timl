" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_schim") || &cp || v:version < 700
  finish
endif
let g:autoloaded_schim = 1

" Section: Misc {{{1

function! s:funcname(name) abort
  return substitute(a:name,'^s:',matchstr(expand('<sfile>'), '<SNR>\d\+_'),'')
endfunction

function! s:function(name) abort
  return function(s:funcname(a:name))
endfunction

let g:schim#nil = []

function! schim#nil_p(val)
  return empty(a:val)
endfunction

function! s:string(val) abort
  if schim#symbol_p(a:val)
    return a:val[0]
  elseif type(a:val) == type('')
    return a:val
  elseif type(a:val) == type(function('tr'))
    let name = join([a:val])
    return (name =~# '^\d' ? '{' . name . '}' : name)
  else
    return string(a:val)
  endif
endfunction

" }}}1
" Section: Symbols {{{1

let g:schim#symbols = {}

function! schim#symbol(str)
  let str = type(a:str) == type([]) ? a:str[0] : a:str
  if !has_key(g:schim#symbols, str)
    let g:schim#symbols[str] = [str]
  endif
  return g:schim#symbols[str]
endfunction

function! schim#symbol_p(symbol)
  return type(a:symbol) == type([]) &&
        \ len(a:symbol) == 1 &&
        \ type(a:symbol[0]) == type('') &&
        \ get(g:schim#symbols, a:symbol[0], 0) is a:symbol
endfunction

" From clojure/lange/Compiler.java
let s:munge = {
      \ ':': "_COLON_",
      \ '+': "_PLUS_",
      \ '>': "_GT_",
      \ '<': "_LT_",
      \ '=': "_EQ_",
      \ '~': "_TILDE_",
      \ '!': "_BANG_",
      \ '@': "_CIRCA_",
      \ '#': "_SHARP_",
      \ "'": "_SINGLEQUOTE_",
      \ '"': "_DOUBLEQUOTE_",
      \ '%': "_PERCENT_",
      \ '^': "_CARET_",
      \ '&': "_AMPERSAND_",
      \ '*': "_STAR_",
      \ '|': "_BAR_",
      \ '{': "_LBRACE_",
      \ '}': "_RBRACE_",
      \ '[': "_LBRACK_",
      \ ']': "_RBRACK_",
      \ '/': "_SLASH_",
      \ '\\': "_BSLASH_",
      \ '?': "_QMARK_"}

let s:demunge = {}
for s:key in keys(s:munge)
  let s:demunge[s:munge[s:key]] = s:key
endfor
unlet! s:key

function! schim#munge(var) abort
  let var = s:string(a:var)
  return tr(substitute(var, '[^[:alnum:]#_-]', '\=get(s:munge,submatch(0))', 'g'), '-', '_')
endfunction

function! schim#demunge(var) abort
  let var = s:string(a:var)
  return tr(substitute(a:var, '_\(\u\+\)_', '\=get(s:demunge, submatch(0), submatch(0))', 'g'), '_', '-')
endfunction

function! schim#a2env(a)
  let env = {'...': a:a['000']}
  for [k,V] in items(a:a)
    if k !~# '^\d'
      let env[schim#demunge(k)] = V
    endif
    unlet! V
  endfor
  return env
endfunction

" }}}1
" Section: Garbage collection {{{1

if !exists('g:schim#closures')
  let g:schim#closures = {}
endif

function! schim#gc()
  let l:count = 0
  for fn in keys(g:schim#closures)
    try
      if fn =~# '^\d'
        let Fn = function('{'.fn.'}')
      else
        let Fn = function(fn)
      endif
    catch /^Vim\%((\a\+)\)\=:E700/
      call remove(g:schim#closures, fn)
      let l:count += 1
    endtry
  endfor
  return l:count
endfunction

augroup schim#gc
  autocmd!
  autocmd CursorHold * call schim#gc()
augroup END

" }}}1
" Section: Eval {{{1

function! schim#lookup(envs, sym) abort
  let sym = type(a:sym) == type([]) ? a:sym[0] : a:sym
  if sym =~# '^f:' && exists('*'.sym[2:-1])
    return function(sym[2:-1])
  elseif sym =~# '^&.\|^\w:' && exists(sym)
    return eval(sym)
  elseif sym =~# '#'
    let sym = schim#munge(sym)
    call schim#autoload(sym)
    if exists('g:'.sym)
      return g:{sym}
    elseif exists('*'.sym)
      return function(sym)
    else
      throw 'schim.vim: ' . sym . ' undefined'
    endif
  endif
  let env = schim#find(a:envs, sym)
  if type(env) ==# type({})
    return env[sym]
  else
    let target = schim#munge(env.'#'.sym)
    if exists('*'.target)
      return function(target)
    else
      return g:{target}
    endif
  endif
endfunction

function! schim#find(envs, sym) abort
  let sym = type(a:sym) == type([]) ? a:sym[0] : a:sym
  for env in a:envs
    if type(env) == type({}) && has_key(env, sym)
      return env
    elseif type(env) == type('')
      let target = schim#munge(env.'#'.sym)
      call schim#autoload(target)
      if exists('*'.target) || exists('g:'.target)
        return env
      endif
    endif
    unlet! env
  endfor
  throw 'schim.vim: ' . sym . ' undefined'
endfunction

let s:macros = {}

function! s:build_function(name, params) abort
  let params = map(copy(a:params), 'v:val is schim#symbol("...") ? "..." : schim#munge(v:val[0])')
  let dict = {}
  return 'function! '.a:name.'('.join(params, ',').")\n"
        \ . "let g:file = expand('<sfile>')\n"
        \ . "let name = matchstr(expand('<sfile>'), '.*\\%(\\.\\.\\| \\)\\zs.*')\n"
        \ . "let fn = g:schim#closures[name]\n"
        \ . "let envs = [schim#a2env(a:)] + fn.envs\n"
        \ . "return schim#eval(fn.exp, envs)\n"
        \ . "endfunction"
endfunction

function! s:lambda(params, form, env) abort
  let dict = {}
  execute s:build_function('dict.function', a:params)
  let name = matchstr(string(dict.function), "'\\zs.*\\ze'")
  let g:schim#closures[name] = { 'envs': a:env, 'exp': a:form }
  return dict.function
endfunction

function! s:file4ns(ns) abort
  if !exists('s:tempdir')
    let s:tempdir = tempname()
  endif
  let file = s:tempdir . '/' . tr(a:ns, '#', '/') . '.vim'
  if !isdirectory(fnamemodify(file, ':h'))
    call mkdir(fnamemodify(file, ':h'), 'p')
  endif
  return file
endfunction

function! schim#set_bang(envs, sym, val)
    let sym = schim#symbol(a:sym)[0]
    let val = a:val
    if sym =~# '^&'
      if type(val) == type([])
        exe 'let ' . sym . ' = join(val, ",")'
      else
        exe 'let ' . sym . ' = val'
      endif
    elseif sym =~# '^[bwtg]:'
      exe 'unlet! '.sym
      exe 'let ' . sym . ' = val'
    elseif sym =~# '^v:'
      exe 'let ' . sym . ' = val'
    else
      let env = schim#find(a:envs, sym)
      let env[sym] = val
    endif
    return val
endfunction

function! schim#eval(x, ...) abort
  let envs = ['user', 'schim#core', 'schim#runtime']
  if a:0 && type(a:1) == type([])
    let envs = a:1
  elseif a:0
    let envs[0] = a:1
  endif
  return s:eval(a:x, envs)
endfunction

function! s:eval(x, envs) abort

  let x = schim#expand_quotes(a:x)
  let envs = a:envs

  let i = 0
  while i < len(envs) && type(envs[i]) != type('')
    let i += 1
  endwhile
  let ns = envs[i]

  if schim#symbol_p(x)
    return schim#lookup(envs, x)

  elseif type(x) != type([]) || empty(x)
    return x

  elseif schim#symbol('quote') is x[0]
    return get(x, 1, g:schim#nil)

  elseif schim#symbol('set!') is x[0]
    if len(x) != 3
      throw 'schim.vim:E119: set! requires 2 arguments'
    endif
    return schim#set_bang(envs, x[1], s:eval(x[2], envs))

  elseif schim#symbol('if') is x[0]
    if len(x) < 3
      throw 'schim.vim:E119: if requires 2 or 3 arguments'
    endif
    let cond = s:eval(x[1], envs)
    return s:eval(get(x, empty(cond) || cond is 0 ? 3 : 2, g:schim#nil), envs)

  elseif schim#symbol('defun') is x[0]
    if len(x) != 4
      throw 'schim.vim:E119: defun requires 3 arguments'
    endif
    let var = s:string(x[1])
    let params = x[2]
    let name = schim#munge(ns.'#'.var)
    let file = s:file4ns(ns)
    call writefile(split(s:build_function(name, x[2]),"\n"), file)
    execute 'source '.file
    let g:schim#closures[name] = {'envs': envs, 'exp': x[3]}
    return function(name)

  elseif schim#symbol('define') is x[0] || schim#symbol('defvar') is x[0]
    if len(x) != 3
      throw 'schim.vim:E119: defvar requires 2 arguments'
    endif
    let var = s:string(x[1])
    let Val = s:eval(x[2], envs)
    let g:{schim#munge(ns.'#'.var)} = Val
    return Val

  elseif schim#symbol('defmacro') is x[0]
    if len(x) != 4
      throw 'schim.vim:E119: defmacro requires 3 arguments'
    endif
    let [_, var, bindings, exp] = x
    let s:macros[var[0]] = exp

  elseif schim#symbol('lambda') is x[0] || schim#symbol("\u03bb") is x[0]
    if len(x) < 3
      throw 'schim.vim:E119: lambda requires at least 2 arguments'
    endif
    return s:lambda(x[1], x[2], envs)

  elseif schim#symbol('let') is x[0]
    let [_, bindings; body] = x
    let env = {}
    for i in range(0, len(bindings)-1, 2)
      if bindings[i][0] ==# '_'
        call s:eval(bindings[i+1], [env] + envs)
      else
        let env[bindings[i][0]] = s:eval(bindings[i+1], [env] + envs)
      endif
    endfor
    return s:eval([schim#symbol('begin')] + body, [env] + envs)

  elseif schim#symbol('begin') is x[0]
    return get(map(x[1:-1], 's:eval(v:val, envs)'), -1, g:schim#nil)

  elseif schim#symbol_p(x[0]) && x[0][0] =~# '^:'
    let strings = map(x[1:-1], 's:string(s:eval(v:val, envs))')
    execute x[0][0] . ' ' . join(strings, ' ')
    return g:schim#nil

  else
    let evaled = map(copy(x), 's:eval(v:val, envs)')
    if type(evaled[0]) == type({})
      let dict = evaled[0]
      if type(evaled[1]) == type(function('tr'))
        let Func = evaled[1]
      else
        let Func = evaled[0][schim#symbol(evaled[1])[0]]
      endif
      let args = evaled[2:-1]
    else
      let dict = {}
      let Func = evaled[0]
      let args = evaled[1:-1]
    endif

    return call(Func, args, dict)
  endif
endfunction

" }}}1
" Section: Read {{{1

let s:iskeyword = '[[:alnum:]_=!#$%^&*+|.?/<>:~-]'

function! s:tokenize(str) abort
  let tokens = []
  let i = 0
  let len = len(a:str)
  while i < len
    let ch = matchstr(a:str, '.', i)
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
    else
      call add(tokens, ch)
      let i += len(ch)
    endif
  endwhile
  return tokens
endfunction

function! schim#tokenize(str)
  return s:tokenize(a:str)
endfunction

function! s:read_one(tokens, i) abort
  let error = 'schim.vim: unexpected EOF'
  let i = a:i
  while i < len(a:tokens)
    if a:tokens[i] =~# '^"\|^-\=\d'
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
          let error = 'schim.vim: dict keys must be strings'
        elseif a:tokens[i] ==# '}'
          let error = 'schim.vim: dict literal contains odd number of elements'
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
      return [g:schim#nil, i+1]
    elseif a:tokens[i] ==# "'"
        let [val, i] = s:read_one(a:tokens, i+1)
        return [[schim#symbol('quote'), val], i]
    elseif a:tokens[i] ==# '`'
        let [val, i] = s:read_one(a:tokens, i+1)
        return [[schim#symbol('quasiquote'), val], i]
    elseif a:tokens[i] ==# ','
        let [val, i] = s:read_one(a:tokens, i+1)
        return [[schim#symbol('unquote'), val], i]
    elseif a:tokens[i][0] ==# ';'
      let i += 1
      continue
    elseif a:tokens[i] =~# '^'.s:iskeyword
      return [schim#symbol(a:tokens[i]), i+1]
    else
      let error = 'schim.vim: unexpected token: '.string(a:tokens[i])
      break
    endif
  endwhile
  throw error
endfunction

function! schim#expand_quotes(token) abort
  if type(a:token) == type({})
    let dict = {}
    for [k, V] in items(a:token)
      let dict[k] = schim#expand_quotes(V)
      unlet! V
    endfor
    return dict
  elseif schim#symbol_p(a:token) || type(a:token) !=# type([]) || empty(a:token)
    return a:token
  elseif schim#symbol_p(a:token[0]) && has_key(s:macros, a:token[0][0])
      throw "MACRO CALLED!!!!!!!!!1!"
    " else token[0] is schim#symbol_p('quasiquote')

    " else token[0] is schim#symbol_p('unquote')

  else
    return a:token
  endif
endfunction

function! schim#read_all(str) abort
  let tokens = s:tokenize(a:str)
  let forms = []
  let i = 0
  while i < len(tokens)
    let [form, i] = s:read_one(tokens, i)
    call add(forms, form)
  endwhile
  return forms
endfunction

function! schim#read(str) abort
  return s:read_one(s:tokenize(a:str), 0)[0]
endfunction

function! schim#re(str, ...) abort
  return call('schim#eval', [schim#read(a:str)] + a:000)
endfunction

function! schim#rep(...) abort
  return schim#pr_str(call('schim#re', a:000))
endfunction

function! schim#readfile(filename) abort
  return schim#read_all(join(readfile(a:filename), "\n"))
endfunction

function! schim#source(filename, ...)
  for expr in schim#readfile(a:filename)
    call call('schim#eval', [expr] + a:000)
  endfor
endfunction

if !exists('s:requires')
  let s:requires = {}
endif

function! schim#autoload(function, ...) abort
  let ns = matchstr(a:function, '.*\ze#')

  if !has_key(s:requires, ns)
    let s:requires[ns] = 1
    if !a:0
      execute 'runtime! autoload/'.tr(ns,'#','/').'.vim'
    endif
    for file in findfile('autoload/'.tr(ns,'#','/').'.schim', &rtp, -1)
      call schim#source(file, ns)
    endfor
  endif
endfunction

" }}}1
" Section: Print {{{1

let s:escapes = {
      \ "\b": '\b',
      \ "\e": '\e',
      \ "\f": '\f',
      \ "\n": '\n',
      \ "\r": '\r',
      \ "\t": '\t',
      \ "\"": '\"',
      \ "\\": '\\'}

function! schim#pr_str(x)
  " TODO: guard against recursion
  if schim#symbol_p(a:x)
    return a:x[0]
  elseif a:x is# g:schim#nil
    return 'nil'
  elseif type(a:x) == type([])
    return '(' . join(map(copy(a:x), 'schim#pr_str(v:val)'), ' ') . ')'
  elseif type(a:x) == type({})
    let acc = []
    for [k, V] in items(a:x)
      call add(acc, schim#pr_str(k) . ' ' . schim#pr_str(V))
      unlet! V
    endfor
    return '{' . join(acc, ' ') . '}'
  elseif type(a:x) == type('')
    return '"'.substitute(a:x, "[\001-\037\"\\\\]", '\=get(s:escapes, submatch(0), printf("\\%03o", char2nr(submatch(0))))', 'g').'"'
  elseif type(a:x) == type(function('tr'))
    return '#function:'.join([a:x])
  else
    return string(a:x)
  endif
endfunction

" }}}1
" Section: Tests {{{1

if !exists('$TEST')
  finish
endif

command! -nargs=1 SchimAssert
      \ try |
      \   if !eval(<q-args>) |
      \     echomsg "Failed: ".<q-args> |
      \   endif |
      \ catch /.*/ |
      \  echomsg "Error:  ".<q-args>." (".v:exception.")" |
      \ endtry

SchimAssert schim#read('foo') ==# schim#symbol('foo')
SchimAssert schim#read('":)"') ==# ':)'
SchimAssert schim#read('(car (list 1 2))') ==# [schim#symbol('car'), [schim#symbol('list'), 1, 2]]
SchimAssert schim#read('{"a" 1 "b" 2}') ==# {"a": 1, "b": 2}
SchimAssert schim#read("(1)\n; hi\n") ==# [1]
SchimAssert schim#read('({})') ==# [{}]
SchimAssert schim#read("'(1 2 3)") ==# [schim#symbol('quote'), [1, 2, 3]]
SchimAssert schim#read("`foo") ==# [schim#symbol('quasiquote'), schim#symbol('foo')]
SchimAssert schim#read(",foo") ==# [schim#symbol('unquote'), schim#symbol('foo')]

SchimAssert schim#re('(+ 1 2 3)') == 6

SchimAssert schim#re('(let () (defvar forty-two 42))')
SchimAssert schim#re('forty-two') ==# 42

SchimAssert schim#re('(if 1 forty-two 69)') ==# 42
SchimAssert schim#re('(if 0 "boo" "yay")') ==# "yay"
SchimAssert schim#re('(begin 1 2)') ==# 2

SchimAssert schim#re('(set! g:schim_set_bang (+ 1 2))') == 3
SchimAssert g:schim_set_bang ==# 3
unlet! g:schim_set_bang
SchimAssert schim#re('(let (a 1) (let (b 2) (set! a 3)) a)') == 3
SchimAssert schim#re('(let (a 1) (let (a 2) (set! a 3)) a)') == 1

SchimAssert schim#re('(dict "a" 1 "b" 2)') ==# {"a": 1, "b": 2}
SchimAssert schim#re('(dict "a" 1 (list "b" 2))') ==# {"a": 1, "b": 2}
SchimAssert schim#re('(length "abc")') ==# 3

SchimAssert schim#re('(reduce + 0 (list 1 2 3))') ==# 6

delcommand SchimAssert

" }}}1

" vim:set et sw=2:
