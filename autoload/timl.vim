" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl")
  finish
endif
let g:autoloaded_timl = 1

" Section: Misc {{{1

function! s:funcname(name) abort
  return substitute(a:name,'^s:',matchstr(expand('<sfile>'), '<SNR>\d\+_'),'')
endfunction

function! s:function(name) abort
  return function(s:funcname(a:name))
endfunction

function! s:persistent_list(...)
  return a:000
endfunction

if !exists('g:timl#nil')
  let g:timl#nil = s:persistent_list()
endif

function! s:string(val) abort
  if timl#symbolp(a:val)
    return a:val[0]
  elseif type(a:val) == type('')
    return a:val
  elseif type(a:val) == type(function('tr'))
    return join([a:val])
  elseif type(a:val) == type([])
    return join(map(copy(a:val), 's:string(v:val)'), ',').','
  else
    return string(a:val)
  endif
endfunction

" }}}1
" Section: Symbols {{{1

if !exists('g:timl#symbols')
  let g:timl#symbols = {}
endif

function! timl#symbol(str)
  let str = type(a:str) == type([]) ? a:str[0] : a:str
  if !has_key(g:timl#symbols, str)
    let g:timl#symbols[str] = s:persistent_list(str)
  endif
  return g:timl#symbols[str]
endfunction

function! timl#symbolp(symbol)
  return type(a:symbol) == type([]) &&
        \ len(a:symbol) == 1 &&
        \ type(a:symbol[0]) == type('') &&
        \ get(g:timl#symbols, a:symbol[0], 0) is a:symbol
endfunction

" From clojure/lange/Compiler.java
let s:munge = {
      \ '0': "_ZERO_",
      \ '1': "_ONE_",
      \ '2': "_TWO_",
      \ '3': "_THREE_",
      \ '4': "_FOUR_",
      \ '5': "_FIVE_",
      \ '6': "_SIX_",
      \ '7': "_SEVEN_",
      \ '8': "_EIGHT_",
      \ '9': "_NINE_",
      \ ',': "_COMMA_",
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

function! timl#munge(var) abort
  let var = s:string(a:var)
  return tr(substitute(var, '[^[:alnum:]:#_-]', '\=get(s:munge,submatch(0), submatch(0))', 'g'), '-', '_')
endfunction

function! timl#demunge(var) abort
  let var = s:string(a:var)
  return tr(substitute(a:var, '_\(\u\+\)_', '\=get(s:demunge, submatch(0), submatch(0))', 'g'), '_', '-')
endfunction

function! timl#a2env(f, a) abort
  let env = {}
  if get(a:f.arglist, -1) is timl#symbol('...')
    let env['...'] = a:a['000']
  endif
  let _ = {}
  for [k,_.V] in items(a:a)
    if k !~# '^\d'
      let k = timl#demunge(k)
      if k =~# ',$'
        let keys = split(k, ',')
        for i in range(len(keys))
          if type(_.V) == type([])
            let env[keys[i]] = get(_.V, i, g:timl#nil)
          elseif type(_.V) == type({})
            let env[keys[i]] = get(_.V, keys[i], g:timl#nil)
          endif
        endfor
      else
        let env[k] = _.V
      endif
    endif
  endfor
  return env
endfunction

function! timl#l2env(f, args) abort
  let args = a:args
  let env = {}
  let _ = {}
  let i = 0
  for _.param in a:f.arglist
    if i >= len(args)
      throw 'timl.vim: arity error'
    endif
    if timl#symbolp(_.param)
      let env[_.param[0]] = args[i]
    elseif type(_.param) == type([])
      for j in range(len(_.param))
        let key = s:string(_.param[j])
        if type(args[i]) == type([])
          let env[key] = get(args[i], j, g:timl#nil)
        elseif type(args[i]) == type({})
          let env[key] = get(args[i], key, g:timl#nil)
        endif
      endfor
    else
      throw 'timl.vim: unsupported param '.string(param)
    endif
    let i += 1
  endfor
  TLinspect env
  return env
endfunction

" }}}1
" Section: Garbage collection {{{1

if !exists('g:timl#lambdas')
  let g:timl#lambdas = {}
endif

function! timl#gc()
  let l:count = 0
  for fn in keys(g:timl#lambdas)
    try
      if fn =~# '^\d'
        let Fn = function('{'.fn.'}')
      else
        let Fn = function(fn)
      endif
    catch /^Vim\%((\a\+)\)\=:E700/
      call remove(g:timl#lambdas, fn)
      let l:count += 1
    endtry
  endfor
  return l:count
endfunction

augroup timl#gc
  autocmd!
  autocmd CursorHold * call timl#gc()
augroup END

" }}}1
" Section: Eval {{{1

let g:user#_STAR_uses_STAR_ = [timl#symbol('timl#repl'), timl#symbol('timl#core')]

function! timl#ns_for_file(file) abort
  let file = fnamemodify(a:file, ':p')
  let slash = exists('+shellslash') && &shellslash ? '\' : '/'
  for dir in split(&runtimepath, ',')
    if file[0 : len(dir)+9] ==# dir.slash.'autoload'.slash
      return tr(fnamemodify(file[len(dir)+10 : -1], ':r:r'), '\/_', '##-')
    endif
  endfor
  return 'user'
endfunction

function! timl#lookup(envs, sym) abort
  let sym = type(a:sym) == type([]) ? a:sym[0] : a:sym
  if sym =~# '^f:' && exists('*'.sym[2:-1])
    return function(sym[2:-1])
  elseif sym =~# '^&.\|^\w:' && exists(sym)
    return eval(sym)
  elseif sym =~# '^@.$'
    return eval(sym)
  elseif sym =~# '#'
    let sym = timl#munge(sym)
    call timl#autoload(sym)
    if exists('g:'.sym)
      return g:{sym}
    elseif exists('*'.sym)
      return function(sym)
    else
      throw 'timl.vim: ' . sym . ' undefined'
    endif
  endif
  let env = timl#find(a:envs, sym)
  if type(env) ==# type({})
    return env[sym]
  else
    let target = timl#munge(env.'#'.sym)
    if exists('*'.target)
      return function(target)
    else
      return g:{target}
    endif
  endif
endfunction

function! timl#find(envs, sym) abort
  let sym = type(a:sym) == type([]) ? a:sym[0] : a:sym
  for env in a:envs
    if type(env) == type({}) && has_key(env, sym)
      return env
    elseif type(env) == type('')
      let target = timl#munge(env.'#'.sym)
      call timl#autoload(target)
      if exists('*'.target) || exists('g:'.target)
        return env
      endif
      for use in get(g:, timl#munge(env.'#*uses*'), [timl#symbol('timl#core')])
        let target = timl#munge(s:string(use).'#'.sym)
        call timl#autoload(target)
        if exists('*'.target) || exists('g:'.target)
          return s:string(use)
        endif
      endfor
    endif
    unlet! env
  endfor
  throw 'timl.vim: ' . sym . ' undefined'
endfunction

function! timl#function(sym, ...) abort
  let t = type(function('tr'))
  if type(a:sym) == t
    return a:sym
  endif
  let demunged = type(a:sym) == type([]) ? a:sym[0] : a:sym
  let munged = timl#munge(demunged)
  if demunged =~# '^\d\+$' && exists('*{'.demunged.'}')
    return function('{'.demunged.'}')
  elseif munged =~# '^f:' && exists('*'.munged[2:-1])
    return function(munged[2:-1])
  elseif demunged =~# '^\w:' && exists(munged) && type(eval(munged)) == t
    return eval(dunged)
  elseif demunged =~# '#'
    call timl#autoload(munged)
    if exists('*'.demunged)
      return function(demunged)
    elseif exists('g:'.demunged) && type(eval(demunged)) == t
      return g:{demunged}
    else
      throw 'timl.vim: no such function ' . demunged
    endif
  endif
  for env in a:0 ? a:1 : []
    if type(env) == type({}) && has_key(env, demunged) && type(env[demunged]) == t
      return env[demunged]
    elseif type(env) == type('')
      let target = timl#munge(env.'#'.demunged)
      call timl#autoload(env.'#'.demunged)
      if exists('*'.target)
        return function(target)
      endif
      for use in get(g:, timl#munge(env.'#*uses*'), [timl#symbol('timl#core')])
        let target = timl#munge(s:string(use).'#'.demunged)
        call timl#autoload(target)
        if exists('*'.target)
          return function(target)
        endif
      endfor
    endif
    unlet! env
  endfor
  throw 'timl.vim: no such function ' . demunged
endfunction

function! timl#qualify(envs, sym)
  let sym = type(a:sym) == type([]) ? a:sym[0] : a:sym
  try
    let ns = timl#find(a:envs, a:sym)
    if type(ns) == type('')
      return timl#symbol(ns . '#' . sym)
    endif
  catch /^timl.vim:/
  endtry
  return a:sym
endfunction

if !exists('s:macros')
  let s:macros = {}
endif

let g:timl#macros = s:macros

function! s:build_function(name, arglist) abort
  let arglist = map(copy(a:arglist), 'v:val is timl#symbol("...") ? "..." : timl#munge(v:val)')
  let dict = {}
  return 'function! '.a:name.'('.join(arglist, ',').")\n"
        \ . "let name = matchstr(expand('<sfile>'), '.*\\%(\\.\\.\\| \\)\\zs.*')\n"
        \ . "let fn = g:timl#lambdas[name]\n"
        \ . "let env = [timl#a2env(fn, a:)] + fn.env\n"
        \ . "let _ = {}\n"
        \ . "let _.result = timl#eval(fn.form, env)\n"
        \ . "while type(_.result) == type([]) && get(_.result, 0) is# g:timl#recur_token\n"
        \ . "let env = [timl#l2env(fn, _.result[1:-1])] + fn.env\n"
        \ . "let _.result = timl#eval(fn.form, env)\n"
        \ . "endwhile\n"
        \ . "return _.result\n"
        \ . "endfunction"
endfunction

function! s:lambda(arglist, form, ns, env) abort
  let dict = {}
  execute s:build_function('dict.function', a:arglist)
  let name = matchstr(string(dict.function), "'\\zs.*\\ze'")
  let g:timl#lambdas[name] = {
        \ 'ns': a:ns,
        \ 'name': name,
        \ 'arglist': a:arglist,
        \ 'env': a:env,
        \ 'form': a:form,
        \ 'macro': 0}
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

function! timl#setq(envs, sym, val, ...)
  let sym = timl#symbol(a:sym)[0]
  let val = s:eval((a:0 ? a:000[-1] : a:val), a:envs)
  let _ = {}
  if sym =~# '^[&@]'
    if type(val) == type([])
      exe 'let ' . sym . ' = join(val, ",")'
    else
      exe 'let ' . sym . ' = val'
    endif
    return val
  elseif sym =~# '^[bwtgv]:'
    let _.env = eval(sym[0:1])
    let sym = timl#munge(sym[2:-1])
  elseif sym =~# '#'
    let _.env = matchstr(sym, '.*\ze#')
    let sym = matchstr(sym, '.*#\zs.*')
  else
    let _.env = timl#find(a:envs, sym)
  endif
  let refs = ''
  for _.form in (a:0 ? [a:val] : []) + a:000[0:-2]
    let _.val = s:eval(_.form, a:envs)
    if timl#symbolp(_.val) || type(_.val) == type('') || type(_.val) == type(0)
      let refs .= '['.string(s:string(_.val)).']'
    elseif type(_.val) == type([]) && len(_.val) == 2
      let refs .= '['.string(_.val[0]).' : '.string(_.val[1]).']'
    else
      throw "timl.vim: invalid setq key ".string(_.val)
    endif
  endfor
  if type(_.env) == type({})
    let pre = '_.env[sym]'
  else
    let pre = 'g:'.timl#munge(s:string(_.env).'#'.sym)
    exe 'unlet! '.pre
  endif
  execute 'let '.pre.refs.' = val'
  return val
endfunction

if !exists('g:timl#core#_STAR_ns_STAR_')
  let g:timl#core#_STAR_ns_STAR_ = 'user'
endif

function! timl#eval(x, ...) abort
  let envs = [g:timl#core#_STAR_ns_STAR_]
  if a:0 && timl#symbolp(a:1)
    let envs[0] = a:1[0]
  elseif a:0 && type(a:1) == type([])
    let envs = a:1
  elseif a:0
    let envs[0] = a:1
    let g:timl#core#_STAR_ns_STAR_ = a:1
  endif

  return s:eval(a:x, envs)
endfunction

if !exists('g:timl#recur_token')
  let g:timl#recur_token = s:persistent_list('recur token')
endif

function! s:eval(x, envs) abort
  let x = a:x
  let envs = a:envs

  let ns = g:timl#core#_STAR_ns_STAR_

  if timl#symbolp(x)
    return timl#lookup(envs, x)

  elseif type(x) == type({})
    return map(copy(x),  's:eval(v:val, envs)')

  elseif type(x) != type([]) || empty(x)
    return x

  elseif timl#symbol('function') is x[0]
    return timl#function(x[1], envs)

  elseif timl#symbol('quote') is x[0]
    return get(x, 1, g:timl#nil)

  elseif timl#symbol('quasiquote') is x[0]
    let s:gensym_id = get(s:, 'gensym_id', 0) + 1
    return s:quasiquote(get(x, 1, g:timl#nil), envs, s:gensym_id)

  elseif timl#symbol('setq') is x[0]
    if len(x) < 3
      throw 'timl.vim:E119: setq requires 2 arguments'
    endif
    return call('timl#setq', [envs] + x[1:-1])

  elseif timl#symbol('if') is x[0]
    if len(x) < 3
      throw 'timl.vim:E119: if requires 2 or 3 arguments'
    endif
    let Cond = s:eval(x[1], envs)
    return s:eval(get(x, empty(Cond) || Cond is 0 ? 3 : 2, g:timl#nil), envs)

  elseif timl#symbol('defun') is x[0] || timl#symbol('defmacro') is x[0]
    if len(x) < 4
      throw 'timl.vim:E119: defun requires at least 3 arguments'
    endif
    let var = s:string(x[1])
    let name = timl#munge(ns.'#'.var)
    let file = s:file4ns(ns)
    call writefile(split(s:build_function(name, x[2]),"\n"), file)
    execute 'source '.file
    let macro = timl#symbol('defmacro') is x[0]
    let form = len(x) == 4 ? x[3] : [timl#symbol('do')] + x[3:-1]
    let g:timl#lambdas[name] = {
          \ 'ns': ns,
          \ 'name': name,
          \ 'arglist': x[2],
          \ 'env': envs,
          \ 'form': form,
          \ 'macro': macro}
    if macro
      let s:macros[name] = 1
    endif
    return function(name)

  elseif timl#symbol('defvar') is x[0]
    if len(x) != 3
      throw 'timl.vim:E119: defvar requires 2 arguments'
    endif
    let var = s:string(x[1])
    let Val = s:eval(x[2], envs)
    let g:{timl#munge(ns.'#'.var)} = Val
    return Val

  elseif timl#symbol('lambda') is x[0] || timl#symbol("\u03bb") is x[0]
    if len(x) < 3
      throw 'timl.vim:E119: lambda requires at least 2 arguments'
    endif
    let form = len(x) == 3 ? x[2] : [timl#symbol('do')] + x[2:-1]
    return s:lambda(x[1], form, ns, envs)

  elseif timl#symbol('recur') is x[0]
    return [g:timl#recur_token] + map(x[1:-1], 's:eval(v:val, envs)')

  elseif x[0] is g:timl#recur_token
    throw 'timl.vim: incorrect use of recur'

  elseif timl#symbol('let') is x[0]
    let env = {}
    let _ = {}
    for [_.key, _.form] in x[1]
      let _.val = s:eval(_.form, [env] + envs)
      if _.key is timl#symbolp('_') || _.key is g:timl#nil
        " ignore
      elseif timl#symbolp(_.key)
        let env[s:string(_.key)] = _.val
      elseif type(_.key) == type([])
        for i in range(len(_.key))
          if type(_.val) == type([])
            let env[s:string(_.key[i])] = get(_.val, i, g:timl#nil)
          elseif type(_.val) == type({})
            let env[s:string(_.key[i])] = get(_.val, s:string(_.key[i]), g:timl#nil)
          endif
        endfor
      else
        throw "timl.vim: unsupported binding form ".timl#pr_str(_.key)
      endif
    endfor
    let form = len(x) == 3 ? x[2] : [timl#symbol('do')] + x[2:-1]
    return s:eval(form, [env] + envs)

  elseif timl#symbol('do') is x[0]
    return get(map(x[1:-1], 's:eval(v:val, envs)'), -1, g:timl#nil)

  elseif timl#symbol('try') is x[0]
    let _ = {}
    let forms = []
    let catches = []
    let finallies = []
    for _.form in x[1:-1]
      if type(_.form) == type([]) && get(_.form, 0) is timl#symbol('catch')
        call add(catches, _.form[1:-1])
      elseif type(_.form) == type([]) && get(_.form, 0) is timl#symbol('finally')
        call extend(finallies, _.form[1:-1])
      else
        call add(forms, _.form)
      endif
    endfor

    if empty(catches)
      try
        return get(map(forms, 's:eval(v:val, envs)'), -1, g:timl#nil)
      finally
        call map(finallies, 's:eval(v:val, envs)')
      endtry
    else
      try
        return get(map(forms, 's:eval(v:val, envs)'), -1, g:timl#nil)
      catch
        for catch in catches
          if v:exception =~# catch[0]
            return get(map(catch[1:-1], 's:eval(v:val, envs)'), -1, g:timl#nil)
          endif
        endfor
        throw v:exception =~# '^Vim' ? 'T'.v:exception[1:-1] : v:exception
      finally
        call map(finallies, 's:eval(v:val, envs)')
      endtry
    endif

  elseif timl#symbolp(x[0]) && x[0][0] =~# '^:'
    let strings = map(x[1:-1], 's:string(s:eval(v:val, envs))')
    execute x[0][0] . ' ' . join(strings, ' ')
    return g:timl#nil

  elseif timl#symbolp(x[0]) && has_key(s:macros, join([timl#lookup(envs, x[0])]))
    let x2 = call(timl#lookup(envs, x[0]), x[1:-1])
    return s:eval(x2, envs)

  else
    if timl#symbolp(x[0])
      let evaled = [timl#function(x[0], envs)] +
            \ map(x[1:-1], 's:eval(v:val, envs)')
    else
      let evaled = map(copy(x), 's:eval(v:val, envs)')
    endif
    if type(evaled[0]) == type({})
      let dict = evaled[0]
      if type(evaled[1]) == type(function('tr'))
        let Func = evaled[1]
      else
        let Func = evaled[0][timl#symbol(evaled[1])[0]]
      endif
      let args = evaled[2:-1]
    elseif type(evaled[0]) == type(function('tr')) || timl#symbolp(evaled[0])
      let dict = {}
      let Func = evaled[0]
      let args = evaled[1:-1]
    else
      throw 'timl.vim: can''t call ' . timl#pr_str(x)
    endif

    return call(Func, args, dict)
  endif
endfunction

function! timl#re(str, ...) abort
  return call('timl#eval', [timl#reader#read_string(a:str)] + a:000)
endfunction

function! timl#rep(...) abort
  return timl#pr_str(call('timl#re', a:000))
endfunction

function! timl#source_file(filename, ...)
  let old_ns = g:timl#core#_STAR_ns_STAR_
  try
    let ns = a:0 ? a:1 : timl#ns_for_file(fnamemodify(a:filename, ':p'))
    let g:timl#core#_STAR_ns_STAR_ = ns
    for expr in timl#reader#read_file(a:filename)
      call timl#eval(expr, ns)
    endfor
  catch /^Vim\%((\a\+)\)\=:E168/
  finally
    let g:timl#core#_STAR_ns_STAR_ = old_ns
  endtry
endfunction

if !exists('g:timl#requires')
  let g:timl#requires = {}
endif

function! timl#autoload(function) abort
  let ns = matchstr(a:function, '.*\ze#')

  if !has_key(g:timl#requires, ns)
    let g:timl#requires[ns] = 1
    call timl#load(ns)
  endif
endfunction

function! timl#load(ns) abort
  execute 'runtime! autoload/'.tr(a:ns,'#','/').'.vim'
  for file in findfile('autoload/'.tr(a:ns,'#','/').'.tim', &rtp, -1)
    call timl#source_file(file, a:ns)
  endfor
endfunction

function! s:quasiquote(token, envs, id) abort
  if type(a:token) == type({})
    let dict = {}
    for [k, V] in items(a:token)
      let dict[k] = s:quasiquote(V, a:envs, a:id)
      unlet! V
    endfor
    return dict
  elseif timl#symbolp(a:token)
    if a:token[0] =~# '#$'
      return timl#symbol(substitute(a:token[0], '#$', '__'.a:id.'__', ''))
    else
      return timl#qualify(a:envs, a:token)
    endif
  elseif type(a:token) !=# type([]) || empty(a:token)
    return a:token
  elseif timl#symbol('unquote') is a:token[0]
    return s:eval(a:token[1], a:envs)
  else
    let ret = []
    for V in a:token
      if type(V) == type([]) && get(V, 0, '') is timl#symbol('unquote-splicing')
        call extend(ret, s:eval(get(V, 1, g:timl#nil), a:envs))
      else
        call add(ret, s:quasiquote(V, a:envs, a:id))
      endif
      unlet! V
    endfor
    return ret
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

function! timl#pr_str(x)
  " TODO: guard against recursion
  if timl#symbolp(a:x)
    return a:x[0]
  elseif a:x is# g:timl#nil
    return 'nil'
  elseif type(a:x) == type([])
    return '(' . join(map(copy(a:x), 'timl#pr_str(v:val)'), ' ') . ')'
  elseif type(a:x) == type({})
    let acc = []
    for [k, V] in items(a:x)
      call add(acc, timl#pr_str(k) . ' ' . timl#pr_str(V))
      unlet! V
    endfor
    return '{' . join(acc, ' ') . '}'
  elseif type(a:x) == type('')
    return '"'.substitute(a:x, "[\001-\037\"\\\\]", '\=get(s:escapes, submatch(0), printf("\\%03o", char2nr(submatch(0))))', 'g').'"'
  elseif type(a:x) == type(function('tr'))
    let name = join([a:x])
    if name =~# '^{.*}$'
      return "#'" . name[1:-2]
    elseif name =~# '#' || name =~# '^\d'
      return "#'" . timl#demunge(name)
    else
      return "#'" . 'f:' . timl#demunge(name)
    endif
  else
    return string(a:x)
  endif
endfunction

" }}}1
" Section: Tests {{{1

if !exists('$TEST')
  finish
endif

command! -nargs=1 TimLAssert
      \ try |
      \   if !eval(<q-args>) |
      \     echomsg "Failed: ".<q-args> |
      \   endif |
      \ catch /.*/ |
      \  echomsg "Error:  ".<q-args>." (".v:exception.")" |
      \ endtry

TimLAssert timl#re('(+ 1 2 3)') == 6

TimLAssert timl#re('(let () (defvar forty-two 42))')
TimLAssert timl#re('forty-two') ==# 42

TimLAssert timl#re('(if 1 forty-two 69)') ==# 42
TimLAssert timl#re('(if 0 "boo" "yay")') ==# "yay"
TimLAssert timl#re('(do 1 2)') ==# 2

TimLAssert timl#re('(setq g:timl_setq {})') == {}
TimLAssert g:timl_setq ==# {}
TimLAssert timl#re('(setq g:timl_setq "key" (list "a" "b"))') == ["a", "b"]
TimLAssert g:timl_setq == {"key": ["a", "b"]}
TimLAssert timl#re('(setq g:timl_setq "key" ''(0 0) ''("c"))') == ["c"]
TimLAssert g:timl_setq == {"key": ["c", "b"]}
unlet! g:timl_setq
TimLAssert timl#re('(let ((a 1)) (let ((b 2)) (setq a 3)) a)') == 3
TimLAssert timl#re('(let ((a 1)) (let ((a 2)) (setq a 3)) a)') == 1

TimLAssert timl#re('(let (((j k) {"j" 1}) ((l m) (list 2))) (list j k l m))') == [1, g:timl#nil, 2, g:timl#nil]
TimLAssert timl#re('(reduce (lambda (m (k v)) (append m (list v k))) ''() {"a" 1})') == [1, "a"]

TimLAssert timl#re('(dict "a" 1 "b" 2)') ==# {"a": 1, "b": 2}
TimLAssert timl#re('(dict "a" 1 (list "b" 2))') ==# {"a": 1, "b": 2}
TimLAssert timl#re('(length "abc")') ==# 3

TimLAssert timl#re('(reduce + 0 (list 1 2 3))') ==# 6

delcommand TimLAssert

" }}}1

" vim:set et sw=2:
