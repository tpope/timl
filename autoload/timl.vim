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

function! timl#gensym(...)
  let s:id = get(s:, 'id', 0) + 1
  return timl#symbol((a:0 ? a:1 : 'G__').s:id)
endfunction

function! timl#truth(val) abort
  return !(empty(a:val) || a:val is 0)
endfunction

" }}}1
" Section: Symbols {{{1

if !exists('g:timl#symbols')
  let g:timl#symbols = {}
  let g:timl#keywords = {}
endif

function! timl#keyword(str)
  let str = type(a:str) == type({}) ? a:str[0] : a:str
  if !has_key(g:timl#keywords, str)
    let g:timl#keywords[str] = {'0': str}
    lockvar g:timl#keywords[str]
  endif
  return g:timl#keywords[str]
endfunction

function! timl#keywordp(keyword)
  return type(a:keyword) == type({}) &&
        \ has_key(a:keyword, 0) &&
        \ type(a:keyword[0]) == type('') &&
        \ get(g:timl#keywords, a:keyword[0], 0) is a:keyword
endfunction

function! timl#intern_type(type)
  return timl#keyword('#'.a:type)
endfunction

let s:symbol = timl#intern_type('timl#lang#Symbol')
function! timl#symbol(str)
  let str = type(a:str) == type({}) ? a:str[0] : a:str
  if !has_key(g:timl#symbols, str)
    let g:timl#symbols[str] = {'0': str, '#tag': s:symbol}
    lockvar g:timl#symbols[str]
  endif
  return g:timl#symbols[str]
endfunction

function! timl#symbolp(symbol, ...)
  return type(a:symbol) == type({}) &&
        \ get(a:symbol, '#tag') is# s:symbol &&
        \ (a:0 ? a:symbol[0] ==# a:1 : 1)
endfunction

function! timl#name(val) abort
  if type(a:val) == type('')
    return a:val
  elseif timl#symbolp(a:val)
    return a:val[0]
  elseif timl#keywordp(a:val)
    return a:val[0]
  else
    throw "timl: no name for ".timl#type(a:val)
  endif
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
  let var = timl#name(a:var)
  return tr(substitute(substitute(var, '[^[:alnum:]:#_-]', '\=get(s:munge,submatch(0), submatch(0))', 'g'), '_SLASH_\ze.', '#', ''), '-', '_')
endfunction

function! timl#demunge(var) abort
  let var = timl#name(a:var)
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
      throw 'timl: arity error: need '.timl#printer#string(a:arglist).' but got '.timl#printer#string(a:args)
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

function! timl#meta(obj)
  if timl#objectp(a:obj)
    return get(a:obj, '#meta', g:timl#nil)
  endif
  return g:timl#nil
endfunction

function! timl#with_meta(obj, meta)
  if timl#objectp(a:obj)
    if !timl#equalsp(get(a:obj, '#meta', g:timl#nil), a:meta)
      let obj = copy(a:obj)
      if a:meta is# g:timl#nil
        call remove(obj, '#meta')
      else
        let obj['#meta'] = a:meta
      endif
      lockvar obj
      return obj
    endif
    return a:obj
  endif
  throw 'timl: cannot attach metadata to a '.timl#type(a:obj)
endfunction

function! timl#objectp(obj)
  return type(a:obj) == type({}) && timl#keywordp(get(a:obj, '#tag')) && a:obj['#tag'][0][0] ==# '#'
endfunction

let s:function = timl#intern_type('timl#lang#Function')
function! timl#functionp(val) abort
  return type(a:val) == type({}) && get(a:val, '#tag') is# s:function
endfunction

function! timl#type(val) abort
  let type = get(s:types, type(a:val), 'timl#vim#unknown')
  if type == 'timl#vim#List' && a:val is# g:timl#nil
    return 'timl#lang#Nil'
  elseif type == 'timl#vim#Dictionary'
    if timl#objectp(a:val)
      return a:val['#tag'][0][1:-1]
    elseif timl#keywordp(a:val)
      return 'timl#lang#Keyword'
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
  elseif timl#symbolp(a:val) || timl#keywordp(a:val)
    return a:val[0]
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
    return string(a:val)
  endif
endfunction

function! timl#num(obj) abort
  if type(a:obj) == type(0) || type(a:obj) == 5
    return a:obj
  endif
  throw "timl: not a number"
endfunction

function! timl#int(obj) abort
  if type(a:obj) == type(0)
    return a:obj
  endif
  throw "timl: not an integer"
endfunction

function! timl#float(obj) abort
  if type(a:obj) == 5
    return a:obj
  endif
  throw "timl: not a float"
endfunction

function! timl#equalsp(x, ...) abort
  for y in a:000
    if type(a:x) != type(y) || a:x !=# y
      return 0
    endif
  endfor
  return 1
endfunction

function! timl#key(key)
  if type(a:key) == type(0)
    return string(a:key)
  elseif timl#keywordp(a:key)
    return a:key[0]
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
    return timl#keyword(a:key)
  endif
endfunction

" }}}1
" Section: Lists {{{1

let s:cons = timl#intern_type('timl#lang#Cons')

let s:ary = type([])

function! timl#seq(coll) abort
  let seq = timl#dispatch("timl#lang#Seqable", "seq", a:coll)
  return empty(seq) ? g:timl#nil : seq
endfunction

function! timl#first(coll) abort
  return type(a:coll) == s:ary ? get(a:coll, 0, g:timl#nil) :
        \ timl#dispatch('timl#lang#ISeq', 'first', timl#seq(a:coll))
endfunction

function! timl#rest(coll) abort
  return timl#dispatch('timl#lang#ISeq', 'rest', timl#seq(a:coll))
endfunction

function! timl#next(coll) abort
  let rest = timl#rest(a:coll)
  return empty(rest) ? g:timl#nil : rest
endfunction

function! timl#get(coll, key, ...) abort
  if a:0
    return timl#dispatch('timl#lang#ILookup', 'get', a:coll, a:key, a:1)
  else
    return timl#dispatch('timl#lang#ILookup', 'get', a:coll, a:key)
  endif
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

function! timl#count(seq) abort
  let i = 0
  let _ = {'seq': a:seq}
  while timl#consp(_.seq)
    let i += 1
    let _.seq = timl#cdr(_.seq)
  endwhile
  return i + len(_.seq)
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

let s:ns = timl#intern_type('timl#lang#Namespace')

function! timl#find_ns(name)
  return get(g:timl#namespaces, timl#name(a:name), g:timl#nil)
endfunction

function! timl#the_ns(name)
  if timl#type(a:name) == 'timl#lang#Namespace'
    return a:name
  endif
  let name = timl#name(a:name)
  if has_key(g:timl#namespaces, name)
    return g:timl#namespaces[name]
  endif
  throw 'timl: no such namespace '.name
endfunction

function! timl#create_ns(name, ...)
  let name = timl#name(a:name)
  if !has_key(g:timl#namespaces, a:name)
    let g:timl#namespaces[a:name] = {'#tag': s:ns, 'name': name, 'referring': [], 'aliases': {}}
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
        \ 'timl.core': {'#tag': s:ns, 'name': 'timl.core', 'referring': [], 'aliases': {}},
        \ 'user':      {'#tag': s:ns, 'name': 'user', 'referring': ['timl.core'], 'aliases': {}}}
endif

if !exists('g:timl#core#_STAR_ns_STAR_')
  let g:timl#core#_STAR_ns_STAR_ = g:timl#namespaces['user']
endif

" }}}1
" Section: Eval {{{1

function! timl#call(Func, args, ...) abort
  if type(a:Func) == type(function('tr'))
    return call(a:Func, a:args, a:0 ? a:1 : {})
  elseif timl#functionp(a:Func)
    return call(a:Func.call, (a:0 ? [a:1] : []) + a:args, a:Func)
  else
    return call('timl#dispatch', ['timl#lang#IFn', 'invoke', a:Func] + (a:0 ? [a:1] : []) + a:args)
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

function! timl#build_exception(exception, throwpoint)
  let dict = {"exception": a:exception}
  let dict.line = +matchstr(a:throwpoint, '\d\+$')
  let dict.qflist = []
  if a:throwpoint !~# '^function '
    let dict.qflist[0] = {"filename": matchstr(a:throwpoint, '^.\{-\}\ze\.\.')}
  endif
  for fn in split(matchstr(a:throwpoint, '\%( \|\.\.\)\zs.*\ze,'), '\.\.')
    call insert(dict.qflist, {'text': fn})
    if has_key(g:timl_functions, fn)
      let dict.qflist[0].filename = g:timl_functions[fn].file
      let dict.qflist[0].lnum = g:timl_functions[fn].line
    else
      try
        redir => out
        exe 'silent verbose function '.(fn =~# '^\d' ? '{'.fn.'}' : fn)
      catch
      finally
        redir END
      endtry
      if fn !~# '^\d'
        let dict.qflist[0].filename = expand(matchstr(out, "\n\tLast set from \\zs[^\n]*"))
        let dict.qflist[0].pattern = '^\s*fu\%[nction]!\=\s*'.substitute(fn,'^<SNR>\d\+_','s:','').'\s*('
      endif
    endif
  endfor
  return dict
endfunction

function! timl#eval(x, ...) abort
  return call('timl#compiler#eval', [a:x] + a:000)
endfunction

function! timl#re(str, ...) abort
  return call('timl#eval', [timl#reader#read_string(a:str)] + a:000)
endfunction

function! timl#rep(...) abort
  return timl#printer#string(call('timl#re', a:000))
endfunction

function! timl#source_file(filename)
  return timl#compiler#source_file(a:filename)
endfunction

if !exists('g:timl#requires')
  let g:timl#requires = {}
endif

function! timl#require(ns) abort
  let ns = timl#name(a:ns)
  if !has_key(g:timl#requires, ns)
    call timl#load(ns)
    let g:timl#requires[ns] = 1
  endif
  return g:timl#nil
endfunction

function! timl#load(ns) abort
  let base = tr(a:ns,'.-','/_')
  if !empty(findfile('autoload/'.base.'.vim'))
    execute 'runtime! autoload/'.base.'.vim'
    return g:timl#nil
  endif
  for file in findfile('autoload/'.base.'.tim', &rtp, -1)
    call timl#source_file(file)
    return g:timl#nil
  endfor
  throw 'timl: could not load '.a:ns
endfunction

call timl#require('timl.core')

" }}}1

" vim:set et sw=2:
