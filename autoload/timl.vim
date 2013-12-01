" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl")
  finish
endif
let g:autoloaded_timl = 1

" Section: Util {{{1

function! s:funcname(name) abort
  return substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),'')
endfunction

function! s:function(name) abort
  return function(s:funcname(a:name))
endfunction

" }}}1
" Section: Data types {{{1

let s:types = {
      \ 0: 'timl#vim#number',
      \ 1: 'timl#vim#string',
      \ 2: 'timl#vim#funcref',
      \ 3: 'timl#vim#list',
      \ 4: 'timl#vim#dictionary',
      \ 5: 'timl#vim#float'}

function! timl#truth(val) abort
  return empty(a:val) || a:val is 0
endfunction

function! timl#type(val) abort
  let type = get(s:types, type(a:val), 'timl#vim#unknown')
  if type == 'timl#vim#list'
    if timl#symbolp(a:val)
      return 'timl#lang#symbol'
    elseif a:val is# g:timl#nil
      return 'timl#lang#nil'
    elseif timl#symbolp(get(a:val, 0)) && a:val[0][0][0] ==# '#'
      return a:val[0][0][1:-1]
    endif
  elseif type == 'timl#vim#dictionary'
    if timl#symbolp(get(a:val, '#tag')) && a:val['#tag'][0][0] ==# '#'
      return a:val['#tag'][0][1:-1]
    endif
  endif
  return type
endfunction

function! timl#implementsp(fn, obj)
  return exists('*'.tr(timl#type(a:obj) . '#' . a:fn, '-', '_'))
endfunction

function! timl#dispatch(fn, obj, ...)
  let t = timl#type(a:obj)
  let fn = tr(t . '#' . a:fn, '-', '_')
  if exists('*'.fn)
    return timl#call(fn, [a:obj] + a:000)
  endif
  throw "timl:E117: can't " . a:fn . " this " . t
endfunction

function! timl#lock(val) abort
  let val = a:val
  lockvar val
  return val
endfunction

function! timl#persistentp(val) abort
  let val = a:val
  return islocked('val')
endfunction

function! timl#persistent(val) abort
  let val = a:val
  if islocked('val')
    return val
  else
    let val = copy(a:val)
    lockvar val
    return val
  endif
endfunction

function! timl#transient(val) abort
  let val = a:val
  if islocked('val')
    return copy(val)
  else
    return val
  endif
endfunction

function! s:freeze(...) abort
  return a:000
endfunction

if !exists('g:timl#nil')
  let g:timl#nil = s:freeze()
  let g:timl#false = g:timl#nil
  let g:timl#true = 1
  lockvar g:timl#nil g:timl#false g:timl#true
endif

function! s:string(val) abort
  if type(a:val) == type('')
    return a:val
  elseif type(a:val) == type(function('tr'))
    return substitute(join([a:val]), '[{}]', '', 'g')
  elseif timl#symbolp(a:val)
    return substitute(a:val[0], '^:', '', '')
  elseif timl#consp(a:val)
    let _ = {'val': a:val}
    let acc = ''
    while timl#consp(_.val)
      let acc .= s:string(timl#car(_.val)) . ','
      let _.val = timl#cdr(_.val)
    endwhile
    return acc
  elseif type(a:val) == type([])
    return join(map(copy(a:val), 's:string(v:val)'), ',').','
  else
    return string(a:val)
  endif
endfunction

function! timl#key(key)
  if type(a:key) == type(0)
    return string(a:key)
  elseif timl#symbolp(a:key) && a:key[0][0] =~# '[:#]'
    return a:key[0][1:-1]
  else
    return ' '.timl#printer#string(a:key)
  endif
endfunction

function! timl#dekey(key)
  if a:key =~# '^#'
    throw 'timl: invalid key '.a:key
  elseif a:key =~# '^ '
    return timl#reader#read_string(a:key[1:-1])
  elseif a:key =~# '^[-+]\=\d'
    return timl#reader#read_string(a:key)
  else
    return timl#symbol(':'.a:key)
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
    let g:timl#symbols[str] = s:freeze(str)
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
  return tr(substitute(var, '_\(\u\+\)_', '\=get(s:demunge, submatch(0), submatch(0))', 'g'), '_', '-')
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
  for _.param in timl#vec(a:f.arglist)
    if i >= len(args)
      throw 'timl: arity error'
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
      throw 'timl: unsupported param '.string(param)
    endif
    let i += 1
  endfor
  return env
endfunction

" }}}1
" Section: Lists {{{1

let s:cons = timl#symbol('#timl#lang#cons')

function! timl#vectorp(obj) abort
  return type(a:obj) == type([]) && a:obj isnot# g:timl#nil && !timl#symbolp(a:obj)
endfunction

function! timl#consp(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '#tag') is# s:cons
endfunction

function! timl#list(...) abort
  return timl#list2(a:000)
endfunction

function! timl#cons(car, cdr) abort
  let cons = {'#tag': s:cons, 'car': a:car, 'cdr': a:cdr}
  lockvar cons
  return cons
endfunction

function! timl#car(cons) abort
  if timl#consp(a:cons)
    return a:cons.car
  endif
  throw 'timl: not a cons cell'
endfunction

function! timl#cdr(cons) abort
  if timl#consp(a:cons)
    return a:cons.cdr
  endif
  throw 'timl: not a cons cell'
endfunction

function! timl#list2(array)
  let _ = {'cdr': g:timl#nil}
  for i in range(len(a:array)-1, 0, -1)
    let _.cdr = timl#cons(a:array[i], _.cdr)
  endfor
  return _.cdr
endfunction

function! timl#vec(cons)
  if !timl#consp(a:cons)
    return copy(a:cons)
  endif
  let array = []
  let _ = {'cons': a:cons}
  while timl#consp(_.cons)
    call add(array, timl#car(_.cons))
    let _.cons = timl#cdr(_.cons)
  endwhile
  return timl#persistent(extend(array, _.cons))
endfunction

function! timl#count(cons) abort
  let i = 0
  let _ = {'cons': a:cons}
  while timl#consp(_.cons)
    let i += 1
    let _.cons = timl#cdr(_.cons)
  endwhile
  return i + len(_.cons)
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
" Section: Namespaces {{{1

let s:ns = timl#symbol('#namespace')

function! timl#create_ns(name, ...)
  let name = s:string(a:name)
  if !has_key(g:timl#namespaces, a:name)
    let g:timl#namespaces[a:name] = {'#tag': s:ns, 'referring': ['timl#core'], 'aliases': {}}
  endif
  let ns = g:timl#namespaces[a:name]
  if !a:0
    return ns
  endif
  let opts = a:1
  let _ = {}
  for _.refer in get(opts, 'referring', [])
    let str = s:string(_.refer)
    if name !=# str && index(ns.referring, str) < 0
      call insert(ns.referring, str)
    endif
  endfor
  for [_.name, _.target] in items(get(opts, 'aliases', {}))
    let ns.aliases[_.name] = s:string(_.target)
  endfor
  return ns
endfunction

if !exists('g:timl#namespaces')
  let g:timl#namespaces = {
        \ 'timl#core': {'#tag': s:ns, 'referring': [], 'aliases': {}},
        \ 'user':      {'#tag': s:ns, 'referring': ['timl#core'], 'aliases': {}}}
endif

" }}}1
" Section: Eval {{{1

function! s:pr_str(x)
  return timl#printer#string(a:x)
endfunction

function! timl#call(Func, args, ...) abort
  let dict = (a:0 && type(a:1) == type({})) ? a:1 : {'__fn__': a:Func}
  if timl#symbolp(a:Func)
    return call('timl#core#get', a:args[0:0] + [a:Func] + a:args[1:-1])
  else
    return call(a:Func, a:args, dict)
  endif
endfunction

function! s:lencompare(a, b)
  return len(a:b) - len(a:b)
endfunction

function! timl#ns_for_file(file) abort
  let file = fnamemodify(a:file, ':p')
  let candidates = []
  for glob in split(&runtimepath, ',')
    let candidates += filter(split(glob(glob), "\n"), 'file[0 : len(v:val)-1] ==# v:val && file[len(v:val)] =~# "[\\/]"')
  endfor
  if empty(candidates)
    return 'user'
  endif
  let dir = sort(candidates, s:function('s:lencompare'))[-1]
  let path = file[len(dir)+1 : -1]
  return substitute(tr(fnamemodify(path, ':r:r'), '\/_', '##-'), '^\%(autoload\|plugin\|test\)#', '', '')
endfunction

function! timl#lookup(sym, ns, locals) abort
  let sym = a:sym[0]
  if sym =~# '^[#:].'
    return a:sym
  elseif sym =~# '^f:' && exists('*'.sym[2:-1])
    return function(sym[2:-1])
  elseif sym =~# '^&.\|^\w:' && exists(sym)
    return eval(sym)
  elseif sym =~# '^@.$'
    return eval(sym)
  elseif sym =~# '.#'
    call timl#autoload(sym)
    let sym = timl#munge(sym)
    if exists('g:'.sym)
      return g:{sym}
    elseif exists('*'.sym)
      return function(sym)
    else
      throw 'timl: ' . sym . ' undefined'
    endif
  elseif has_key(a:locals, sym)
    return a:locals[sym]
  endif
  let ns = timl#find(sym, a:ns)
  if ns isnot# g:timl#nil
    let target = timl#munge(ns.'#'.sym)
    if exists('*'.target)
      return function(target)
    else
      return g:{target}
    endif
  endif
  throw 'timl: ' . sym . ' undefined'
endfunction

function! timl#find(sym, ns) abort
  let sym = type(a:sym) == type([]) ? a:sym[0] : a:sym
  let env = a:ns
  call timl#require(env)
  let ns = timl#create_ns(env)
  if sym =~# './.'
    let alias = matchstr(sym, '.*\ze/')
    let var = matchstr(sym, '.*/\zs.*')
    if has_key(ns.aliases, alias)
      return timl#find([ns.aliases[alias]], var)
    endif
  endif
  let target = timl#munge(env.'#'.sym)
  if exists('*'.target) || exists('g:'.target)
    return env
  endif
  for refer in ns.referring
    let target = timl#munge(s:string(refer).'#'.sym)
    call timl#require(refer)
    if exists('*'.target) || exists('g:'.target)
      return s:string(refer)
    endif
  endfor
  return g:timl#nil
endfunction

function! timl#qualify(envs, sym)
  let sym = type(a:sym) == type([]) ? a:sym[0] : a:sym
  if has_key(a:envs[0], sym)
    return a:sym
  endif
  let ns = timl#find(a:sym, a:envs[1])
  if type(ns) == type('')
    return timl#symbol(ns . '#' . sym)
  endif
  return a:sym
endfunction

function! s:build_function(name, arglist) abort
  let arglist = map(copy(timl#vec(a:arglist)), 'v:val is timl#symbol("...") ? "..." : timl#munge(v:val)')
  let dict = {}
  return 'function! '.a:name.'('.join(arglist, ',').") abort\n"
        \ . "let name = matchstr(expand('<sfile>'), '.*\\%(\\.\\.\\| \\)\\zs.*')\n"
        \ . "let fn = g:timl#lambdas[name]\n"
        \ . "let env = extend(timl#a2env(fn, a:), copy(fn.env), 'keep')\n"
        \ . "let nameenv = {}\n"
        \ . "if !empty(get(fn, 'name', ''))\n"
        \ . "let nameenv = {fn.name[0]: name =~ '^\\d' ? self.__fn__ : function(name)}\n"
        \ . "endif\n"
        \ . "call extend(env, nameenv, 'keep')\n"
        \ . "let _ = {}\n"
        \ . "let _.result = timl#eval(fn.form, fn.ns, env)\n"
        \ . "while type(_.result) == type([]) && get(_.result, 0) is# g:timl#recur_token\n"
        \ . "let env = extend(timl#l2env(fn, _.result[1:-1]), copy(fn.env), 'keep')\n"
        \ . "call extend(env, nameenv, 'keep')\n"
        \ . "let _.result = timl#eval(fn.form, fn.ns, env)\n"
        \ . "endwhile\n"
        \ . "return _.result\n"
        \ . "endfunction"
endfunction

function! s:lambda(name, arglist, form, ns, env) abort
  let dict = {}
  execute s:build_function('dict.function', a:arglist)
  let fn = matchstr(string(dict.function), "'\\zs.*\\ze'")
  let g:timl#lambdas[fn] = {
        \ 'ns': a:ns,
        \ 'arglist': a:arglist,
        \ 'env': a:env,
        \ 'form': a:form,
        \ 'macro': 0}
  if !empty(a:name)
    let g:timl#lambdas[fn].name = a:name
  endif
  return dict.function
endfunction

function! s:file4ns(ns) abort
  if !exists('s:tempdir')
    let s:tempdir = tempname()
  endif
  let file = s:tempdir . '/' . tr(timl#munge(a:ns), '#', '/') . '.vim'
  if !isdirectory(fnamemodify(file, ':h'))
    call mkdir(fnamemodify(file, ':h'), 'p')
  endif
  return file
endfunction

function! s:define_function(opts)
  let munged = timl#munge(s:string(a:opts.ns).'#'.s:string(a:opts.name))
  let file = s:file4ns(a:opts.ns)
  call writefile(split(s:build_function(munged, a:opts.arglist),"\n"), file)
  execute 'source '.file
  let g:timl#lambdas[munged] = a:opts
  return function(munged)
endfunction

function! timl#setq(envs, target, val) abort
  let val = s:eval(a:val, a:envs)
  if timl#symbolp(a:target)
    let unmunged = s:string(a:target)
    let sym = timl#munge(unmunged)
    let _ = {}
    if unmunged =~# '^@.$\|^&'
      if type(val) == type([])
        exe 'let ' . unmunged . ' = join(val, ",")'
      else
        exe 'let ' . unmunged . ' = val'
      endif
      return val
    elseif sym =~# '^[bwtgv]:[[:alpha:]][[:alnum:]_#]*$'
      exe 'unlet! '.sym
      exe 'let '.sym.' = val'
      return val
    elseif sym =~# '^[[:alpha:]][[:alnum:]_#]*$'
      unlet! g:{sym}
      let g:{sym} = val
      return val
    endif
  elseif timl#consp(a:target)
    let target = map(copy(timl#vec(a:target)), 's:eval(v:val, a:envs)')
    if len(target) == 3
          \ && type(target[0]) == type([])
          \ && type(target[1]) == type(0)
          \ && type(target[2]) == type(0)
          \ && type(val)       == type([])
      let target[0][target[1] : target[2]] = val
      return val
    elseif len(target) == 2
          \ && (type(target[0]) == type([]) || type(target[0]) == type({}))
      let target[0][target[1]] = val
      return val
    endif
  endif
  throw 'timl: invalid assignment target ' . s:pr_str(a:target)
endfunction

function! timl#build_exception(exception, throwpoint)
  let dict = {"exception": a:exception}
  let dict.line = +matchstr(a:throwpoint, '\d\+$')
  if a:throwpoint !~# '^function '
    let dict.file = matchstr(a:throwpoint, '^.\{-\}\ze\.\.')
  endif
  let dict.functions = map(split(matchstr(a:throwpoint, '\%( \|\.\.\)\zs.*\ze,'), '\.\.'), 'timl#demunge(v:val)')
  return dict
endfunction

if !exists('g:timl#core#_STAR_ns_STAR_')
  let g:timl#core#_STAR_ns_STAR_ = timl#symbol('user')
endif

function! timl#eval(x, ...) abort
  if a:0 > 1
    return s:eval(a:x, [a:2, s:string(a:1)])
  endif

  if a:0
    let g:timl#core#_STAR_ns_STAR_ = timl#symbol(a:1)
  endif
  let envs = [{}, g:timl#core#_STAR_ns_STAR_[0]]

  return s:eval(a:x, envs)
endfunction

if !exists('g:timl#recur_token')
  let g:timl#recur_token = timl#symbol('#recur')
endif

let s:function         = timl#symbol('function')
let s:quote            = timl#symbol('quote')
let s:quasiquote       = timl#symbol('quasiquote')
let s:unquote          = timl#symbol('unquote')
let s:unquote_splicing = timl#symbol('unquote-splicing')
let s:setq             = timl#symbol('set!')
let s:if               = timl#symbol('if')
let s:define           = timl#symbol('define')
let s:lambda           = timl#symbol('lambda')
let s:recur            = timl#symbol('recur')
let s:let              = timl#symbol('let')
let s:begin            = timl#symbol('begin')
let s:try              = timl#symbol('try')
let s:catch            = timl#symbol('catch')
let s:finally          = timl#symbol('finally')
let s:colon            = timl#symbol(':')

function! s:eval(x, envs) abort
  let x = a:x
  let envs = a:envs

  let ns = g:timl#core#_STAR_ns_STAR_

  if timl#symbolp(x)
    return timl#lookup(x, envs[1], envs[0])

  elseif type(x) == type([]) && x isnot# g:timl#nil
    return map(copy(x), 's:eval(v:val, envs)')

  elseif type(x) != type({})
    return x

  elseif !timl#consp(x)
    if timl#implementsp('eval', x)
      return timl#dispatch('eval', x, envs)
    elseif timl#type(x) == 'timl#vim#dictionary'
      return map(copy(x),  's:eval(v:val, envs)')
    else
      return x
    endif
  endif

  let F = timl#car(x)
  let rest = timl#vec(timl#cdr(x))

  if F is s:function
    return function(s:string(get(rest, 0)))

  elseif F is# s:quote
    return get(rest, 0, g:timl#nil)

  elseif F is# s:quasiquote
    let s:gensym_id = get(s:, 'gensym_id', 0) + 1
    return s:quasiquote(get(rest, 0, g:timl#nil), envs, s:gensym_id)

  elseif F is# s:setq
    if len(rest) < 2
      throw 'timl:E119: set! requires 2 arguments'
    endif
    return call('timl#setq', [envs] + rest)

  elseif F is# s:if
    if len(rest) < 2
      throw 'timl:E119: if requires 2 or 3 arguments'
    endif
    let Cond = s:eval(rest[0], envs)
    return s:eval(get(rest, timl#truth(Cond) ? 2 : 1, g:timl#nil), envs)

  elseif F is# s:define
    if timl#consp(rest[0])
      let proto = timl#vec(rest[0])
      let form = len(rest) == 2 ? rest[1] : timl#list2([s:begin] + rest[1:-1])
      return s:define_function({
            \ 'ns': ns,
            \ 'name': proto[0],
            \ 'arglist': proto[1:-1],
            \ 'env': envs[0],
            \ 'form': form,
            \ 'macro': 0})
    endif
    let var = s:string(rest[0])
    let name = ns[0].'#'.var
    let global = timl#munge(name)
    let Val = s:eval(rest[1], envs)
    unlet! g:{global}
    if exists('*'.global)
      execute 'delfunction '.global
    endif
    if type(Val) == type(function('tr'))
      let munged = timl#munge(Val)
      if has_key(g:timl#lambdas, munged)
        let lambda = g:timl#lambdas[munged]
        call s:define_function({
              \ 'ns': ns,
              \ 'name': timl#symbol(var),
              \ 'arglist': lambda.arglist,
              \ 'env': lambda.env,
              \ 'form': lambda.form,
              \ 'macro': lambda.macro})
      elseif munged =~# '^\d'
        throw 'timl: cannot define anonymous non-TimL function'
      else

        let file = s:file4ns(ns)
        call writefile([
              \ "function! ".global."(...) abort",
              \ "return call(".string(munged).", a:000)",
              \ "endfunction"], file)
        execute 'source '.file
      endif
    else
      let g:{global} = Val
    endif
    return Val

  elseif F is# s:lambda
    if rest[0] is '#cons'
      throw string(rest)
    endif
    if timl#symbolp(get(rest, 0))
      let name = remove(rest, 0)
    else
      let name = ''
    endif
    if type(get(rest, 0)) != type([]) && !timl#consp(get(rest, 0))
      throw 'timl(lambda): parameter list required'
    endif
    let form = len(rest) == 2 ? rest[1] : timl#list2([s:begin] + rest[1:-1])
    return s:lambda(name, rest[0], form, ns[0], envs[0])

  elseif F is# s:recur
    return [g:timl#recur_token] + map(copy(rest), 's:eval(v:val, envs)')

  elseif F is# g:timl#recur_token
    throw 'timl: incorrect use of recur'

  elseif F is# s:let
    let env = copy(envs[0])
    let _ = {}
    for _.list in timl#vec(rest[0])
      let _.let = timl#vec(_.list)
      if timl#symbolp(_.let)
        throw 'timl: let accepts a list of lists'
      elseif len(_.let) != 2
        throw 'timl: invalid binding '.s:pr_str(_.let)
      endif
      let [_.key, _.form] = _.let
      let _.val = s:eval(_.form, [env] + envs[1:-1])
      if _.key is timl#symbolp('_') || _.key is g:timl#nil
        " ignore
      elseif timl#symbolp(_.key)
        let env[s:string(_.key)] = _.val
      elseif type(_.key) == type([])
        let _.array = timl#vec(_.val)
        for i in range(len(_.key))
          if type(_.val) == type([])
            let env[s:string(_.key[i])] = get(_.array, i, g:timl#nil)
          elseif type(_.val) == type({})
            let env[s:string(_.key[i])] = get(_.array, s:string(_.key[i]), g:timl#nil)
          endif
        endfor
      else
        throw 'timl: unsupported binding form '.s:pr_str(_.key)
      endif
    endfor
    let form = len(rest) == 2 ? rest[1] : timl#list2([s:begin] + rest[1:-1])
    return s:eval(form, [env] + envs[1:-1])

  elseif F is# s:begin
    return get(map(copy(rest), 's:eval(v:val, envs)'), -1, g:timl#nil)

  elseif F is# s:try
    let _ = {}
    let forms = []
    let catches = []
    let finallies = []
    for _.form in rest
      if type(_.form) == type([]) && get(_.form, 0) is s:catch
        let _.pattern = s:eval(get(_.form, 1, g:timl#nil), envs)
        if type(_.pattern) ==# type(0)
          let _.pattern = '^Vim\%((\a\+)\)\=:E' . _.pattern
        elseif type(_.pattern) !=# type('')
          throw 'timl: first catch argument must be a string'
        endif
        if !timl#symbolp(get(_.form, 2, g:timl#nil))
          throw 'timl: second catch argument must be a symbol'
        endif
        call add(catches, [_.pattern] + _.form[2:-1])
      elseif type(_.form) == type([]) && get(_.form, 0) is s:finally
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
            let env = copy(envs[0])
            if catch[2] isnot# timl#symbol('_')
              let env[s:string(catch[2])] = timl#build_exception(v:exception, v:throwpoint)
            endif
            return get(map(catch[2:-1], 's:eval(v:val, [env] + envs[1:-1])'), -1, g:timl#nil)
          endif
        endfor
        throw v:exception =~# '^Vim' ? 'T'.v:exception[1:-1] : v:exception
      finally
        call map(finallies, 's:eval(v:val, envs)')
      endtry
    endif

  elseif F is s:colon
    let strings = map(copy(rest), 's:string(s:eval(v:val, envs))')
    execute F[0] . ' ' . join(strings, ' ')
    return g:timl#nil

  else
    if timl#symbolp(F)
      let Fn = timl#lookup(F, envs[1], envs[0])
      if get(get(g:timl#lambdas, s:string(Fn), {}), 'macro')
        return s:eval(timl#call(Fn, rest), envs)
      endif
      let evaled = [Fn] + map(copy(rest), 's:eval(v:val, envs)')
    else
      let evaled = map([F] + rest, 's:eval(v:val, envs)')
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
      let dict = 0
      let Func = evaled[0]
      let args = evaled[1:-1]
    else
      throw 'timl: cannot call ' . s:pr_str(x)
    endif

    return timl#call(Func, args, dict)
  endif
endfunction

function! timl#re(str, ...) abort
  return call('timl#eval', [timl#reader#read_string(a:str)] + a:000)
endfunction

function! timl#rep(...) abort
  return s:pr_str(call('timl#re', a:000))
endfunction

function! timl#source_file(filename, ...)
  let old_ns = g:timl#core#_STAR_ns_STAR_
  try
    let ns = a:0 ? a:1 : timl#ns_for_file(fnamemodify(a:filename, ':p'))
    let g:timl#core#_STAR_ns_STAR_ = timl#symbol(ns)
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
  call timl#require(ns)
endfunction

function! timl#require(ns) abort
  let ns = a:ns
  if !has_key(g:timl#requires, ns)
    let g:timl#requires[ns] = 1
    call timl#load(ns)
  endif
endfunction

function! timl#load(ns) abort
  let base = tr(a:ns,'#-','/_')
  execute 'runtime! autoload/'.base.'.vim'
  for file in findfile('autoload/'.base.'.tim', &rtp, -1)
    call timl#source_file(file, tr(a:ns, '_', '-'))
  endfor
endfunction

function! s:quasiquote(token, envs, id) abort
  if timl#consp(a:token)
    if timl#car(a:token) is s:unquote
      return s:eval(timl#car(timl#cdr(a:token)), a:envs)
    endif
    let ret = []
    let token = timl#vec(a:token)
    for V in token
      if timl#consp(V) && timl#car(V) is# s:unquote_splicing
        call extend(ret, timl#vec(s:eval(timl#car(timl#cdr(V)), a:envs)))
      else
        call add(ret, s:quasiquote(V, a:envs, a:id))
      endif
      unlet! V
    endfor
    return timl#list2(ret)
  elseif type(a:token) == type({})
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
  elseif type(a:token) == type([])
    return map(copy(a:token), 's:quasiquote(v:val, a:envs, a:id)')
  else
    return a:token
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
      \  echomsg "Error:  ".<q-args>." (".v:exception.")" . v:throwpoint |
      \ endtry

TimLAssert timl#re('(+ 1 2 3)') == 6

TimLAssert timl#re('(let () (define forty-two 42))')
TimLAssert timl#re('forty-two') ==# 42

TimLAssert timl#re('(if 1 forty-two 69)') ==# 42
TimLAssert timl#re('(if 0 "boo" "yay")') ==# "yay"
TimLAssert timl#re('(begin 1 2)') ==# 2

TimLAssert timl#re('(set! g:timl_setq (dict))') == {}
TimLAssert g:timl_setq ==# {}
let g:timl_setq = {}
TimLAssert timl#re('(set! (g:timl_setq "key") ["a" "b"])') == ["a", "b"]
TimLAssert g:timl_setq ==# {"key": ["a", "b"]}
let g:timl_setq = {"key": ["a", "b"]}
TimLAssert timl#re('(set! ((f:get g:timl_setq "key") 0 0) ["c"])') == ["c"]
TimLAssert g:timl_setq == {"key": ["c", "b"]}
unlet! g:timl_setq

TimLAssert timl#re('(let (([j k] (dict "j" 1)) ([l m] [2])) [j k l m])') == [1, g:timl#nil, 2, g:timl#nil]
TimLAssert timl#re('(reduce (lambda (m (k v)) (append m (list v k))) ''() (dict "a" 1))') == [1, "a"]

TimLAssert timl#re('(dict "a" 1 "b" 2)') ==# {"a": 1, "b": 2}
TimLAssert timl#re('(dict "a" 1 ["b" 2])') ==# {"a": 1, "b": 2}
TimLAssert timl#re('(length "abc")') ==# 3

TimLAssert timl#re('(reduce + 0 (list 1 2 3))') ==# 6

TimLAssert timl#re("(loop ((n 5) (f 1)) (if (<= n 1) f (recur (1- n) (* f n))))") ==# 120

delcommand TimLAssert

" }}}1

" vim:set et sw=2:
