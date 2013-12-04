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

function! s:freeze(...) abort
  return a:000
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
      \ '.': "#",
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
  let var = timl#str(a:var)
  return tr(substitute(substitute(var, '[^[:alnum:]:#_-]', '\=get(s:munge,submatch(0), submatch(0))', 'g'), '_SLASH_\ze.', '#', ''), '-', '_')
endfunction

function! timl#demunge(var) abort
  let var = timl#str(a:var)
  return tr(substitute(var, '_\(\u\+\)_', '\=get(s:demunge, submatch(0), submatch(0))', 'g'), '_', '-')
endfunction

let s:amp = timl#symbol('&')
function! timl#arg2env(arglist, args, env) abort
  let args = a:args
  let env = a:env
  let _ = {}
  let i = 0
  for _.param in timl#vec(a:arglist)
    if _.param is s:amp
      let env[get(a:arglist, i+1, ['...'])[0]] = args[i : -1]
      break
    elseif i >= len(args)
      throw 'timl: arity error'.i.string(args)
    elseif timl#symbolp(_.param)
      let env[_.param[0]] = args[i]
    elseif type(_.param) == type([])
      for j in range(len(_.param))
        let key = timl#str(_.param[j])
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
" Section: Data types {{{1

let s:types = {
      \ 0: 'timl#vim#Number',
      \ 1: 'timl#vim#String',
      \ 2: 'timl#vim#Funcref',
      \ 3: 'timl#vim#List',
      \ 4: 'timl#vim#Dictionary',
      \ 5: 'timl#vim#Float'}


function! timl#truth(val) abort
  return !(empty(a:val) || a:val is 0)
endfunction

let s:function = timl#symbol('#timl#lang#Function')
function! timl#functionp(val) abort
  return type(a:val) == type({}) && get(a:val, '#tag') is# s:function
endfunction

function! timl#type(val) abort
  let type = get(s:types, type(a:val), 'timl#vim#unknown')
  if type == 'timl#vim#List'
    if timl#symbolp(a:val)
      return 'timl#lang#Symbol'
    elseif a:val is# g:timl#nil
      return 'timl#lang#Nil'
    elseif timl#symbolp(get(a:val, 0)) && a:val[0][0][0] ==# '#'
      return a:val[0][0][1:-1]
    endif
  elseif type == 'timl#vim#Dictionary'
    if timl#symbolp(get(a:val, '#tag')) && a:val['#tag'][0][0] ==# '#'
      return a:val['#tag'][0][1:-1]
    endif
  endif
  return type
endfunction

function! timl#satisfiesp(proto, obj)
  let t = timl#type(a:obj)
  let obj = tr(t, '-', '_')
  if type(get(g:, obj)) == type({})
    let proto = timl#str(a:proto)
    return has_key(get(g:{t}, "implements", {}), proto)
  else
    throw "timl: type " . t . " undefined"
  else
endfunction

runtime! autoload/timl/lang.vim
runtime! autoload/timl/vim.vim
function! timl#dispatch(proto, fn, obj, ...)
  let t = timl#type(a:obj)
  let obj = tr(t, '-', '_')
  if type(get(g:, obj)) == type({})
    let impls = get(g:{t}, "implements", {})
    let proto = timl#str(a:proto)
    if has_key(impls, proto)
      return timl#call(impls[proto][timl#str(a:fn)], [a:obj] + a:000)
    endif
  else
    throw "timl: type " . t . " undefined"
  endif
  throw "timl:E117: ".t." doesn't implement ".a:proto
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

if !exists('g:timl#nil')
  let g:timl#nil = s:freeze()
  let g:timl#false = g:timl#nil
  let g:timl#true = 1
  lockvar g:timl#nil g:timl#false g:timl#true
endif

function! timl#str(val) abort
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
      let acc .= timl#str(timl#car(_.val)) . ','
      let _.val = timl#cdr(_.val)
    endwhile
    return acc
  elseif type(a:val) == type([])
    return join(map(copy(a:val), 'timl#str(v:val)'), ',').','
  else
    let g:wtf = a:val
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
" Section: Lists {{{1

let s:cons = timl#symbol('#timl#lang#Cons')

function! timl#seq(coll) abort
  let seq = timl#dispatch("timl#lang#Seqable", "seq", a:coll)
  return empty(seq) ? g:timl#nil : seq
endfunction

function! timl#consp(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '#tag') is# s:cons
endfunction

function! timl#list(...) abort
  return timl#list2(a:000)
endfunction

function! timl#cons(car, cdr) abort
  if timl#satisfiesp('timl#lang#Seqable', a:cdr)
    let cons = {'#tag': s:cons, 'car': a:car, 'cdr': a:cdr}
    lockvar cons
    return cons
  else
  endif
  throw 'timl: not seqable'
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

function! timl#vectorp(obj) abort
  return type(a:obj) == type([]) && a:obj isnot# g:timl#nil && !timl#symbolp(a:obj)
endfunction

" }}}1
" Section: Namespaces {{{1

let s:ns = timl#symbol('#namespace')

function! timl#create_ns(name, ...)
  let name = timl#str(a:name)
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
    let str = timl#str(_.refer)
    if name !=# str && index(ns.referring, str) < 0
      call insert(ns.referring, str)
    endif
  endfor
  for [_.name, _.target] in items(get(opts, 'aliases', {}))
    let ns.aliases[_.name] = timl#str(_.target)
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

function! timl#call(Func, args) abort
  if type(a:Func) == type(function('tr'))
    return call(a:Func, a:args, {})
  elseif timl#functionp(a:Func)
    return call(a:Func.call, a:args, a:Func)
  else
    return call('timl#dispatch', ['timl#lang#IFn', 'invoke', a:Func] + a:args)
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

function! timl#lookup(sym, ns) abort
  let sym = type(a:sym) == type('') ? a:sym : a:sym[0]
  if sym =~# '^[#:].'
    return a:sym
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
  let sym = type(a:sym) == type('') ? a:sym : a:sym[0]
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
  if exists('g:'.target)
    return env
  endif
  for refer in ns.referring
    let target = timl#munge(timl#str(refer).'#'.sym)
    call timl#require(refer)
    if exists('g:'.target)
      return timl#str(refer)
    endif
  endfor
  return g:timl#nil
endfunction

let s:specials = {
      \ 'if': 1,
      \ 'do': 1,
      \ 'let': 1,
      \ 'fn': 1,
      \ 'def': 1,
      \ ':': 1,
      \ 'quote': 1,
      \ 'syntax-quote': 1,
      \ 'unquote': 1,
      \ 'unquote-splicing': 1,
      \ 'function': 1,
      \ 'try': 1,
      \ 'catch': 1,
      \ 'finally': 1}

function! timl#qualify(sym, ns)
  let sym = type(a:sym) == type('') ? a:sym : a:sym[0]
  if has_key(s:specials, sym) || sym =~# '^\w:'
    return sym
  elseif sym =~# '#' && exists('g:'.timl#munge(sym))
    return 'g:'.sym
  endif
  let ns = timl#find(a:sym, a:ns)
  if type(ns) == type('')
    return timl#symbol('g:' . ns . '#' . sym)
  endif
  throw 'Could not resolve '.a:sym
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
  return call('timl#compiler#eval', [a:x] + a:000)

  if a:0
    let g:timl#core#_STAR_ns_STAR_ = timl#symbol(a:1)
  endif
  let envs = [{}, g:timl#core#_STAR_ns_STAR_[0]]

  return s:eval(a:x, envs)
endfunction

function! timl#re(str, ...) abort
  return call('timl#eval', [timl#reader#read_string(a:str)] + a:000)
endfunction

function! timl#rep(...) abort
  return timl#printer#string(call('timl#re', a:000))
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
  let ns = matchstr(a:function, '.*\ze[#/].')
  call timl#require(ns)
endfunction

function! timl#require(ns) abort
  let ns = tr(a:ns, '#.-', '//_')
  if !has_key(g:timl#requires, ns)
    let g:timl#requires[ns] = 1
    call timl#load(ns)
  endif
endfunction

function! timl#load(ns) abort
  let base = tr(a:ns,'#.-','//_')
  execute 'runtime! autoload/'.base.'.vim'
  for file in findfile('autoload/'.base.'.tim', &rtp, -1)
    call timl#source_file(file, tr(a:ns, '_', '-'))
  endfor
endfunction

" }}}1

" vim:set et sw=2:
