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

" From clojure/lang/Compiler.java
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
  let var = type(a:var) == type('') ? a:var : a:var[0]
  return tr(substitute(substitute(var, '[^[:alnum:]:#_-]', '\=get(s:munge,submatch(0), submatch(0))', 'g'), '_SLASH_\ze.', '#', ''), '-', '_')
endfunction

function! timl#demunge(var) abort
  let var = type(a:var) == type('') ? a:var : a:var[0]
  return tr(substitute(var, '_\(\u\+\)_', '\=get(s:demunge, submatch(0), submatch(0))', 'g'), '_', '-')
endfunction

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
  return type(a:type) ==# type('') ? timl#keyword('#'.a:type) : a:type
endfunction

let s:tag_sentinel = s:freeze('tagged')
function! timl#bless(class, ...) abort
  let obj = a:0 ? a:1 : {}
  let obj['#tagged'] = s:tag_sentinel
  let obj['#tag'] = timl#intern_type(a:class)
  return obj
endfunction

let s:symbol = timl#intern_type('timl.lang/Symbol')
function! timl#symbol(str)
  let str = type(a:str) == type({}) ? a:str[0] : a:str
  if !has_key(g:timl#symbols, str)
    let g:timl#symbols[str] = timl#bless(s:symbol, {'0': str})
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

function! timl#meta(obj) abort
  if timl#objectp(a:obj)
    return get(a:obj, '#meta', g:timl#nil)
  endif
  return g:timl#nil
endfunction

function! timl#with_meta(obj, meta) abort
  if timl#objectp(a:obj)
    if !timl#equalsp(get(a:obj, '#meta', g:timl#nil), a:meta)
      let obj = copy(a:obj)
      if a:meta is# g:timl#nil
        call remove(obj, '#meta')
      else
        let obj['#meta'] = a:meta
      endif
      return timl#persistentb(obj)
    endif
    return a:obj
  endif
  throw 'timl: cannot attach metadata to a '.timl#type(a:obj)
endfunction

function! timl#objectp(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '#tagged') is s:tag_sentinel
endfunction

let s:function = timl#intern_type('timl.lang/Function')
function! timl#functionp(val) abort
  return type(a:val) == type({}) && get(a:val, '#tag') is# s:function
endfunction

let s:types = {
      \ 0: 'timl.vim/Number',
      \ 1: 'timl.vim/String',
      \ 2: 'timl.vim/Funcref',
      \ 3: 'timl.vim/List',
      \ 4: 'timl.vim/Dictionary',
      \ 5: 'timl.vim/Float'}

function! timl#type(val) abort
  let type = get(s:types, type(a:val), 'timl.vim/Unknown')
  if type == 'timl.vim/List' && a:val is# g:timl#nil
    return 'timl.lang/Nil'
  elseif type == 'timl.vim/Dictionary'
    if timl#objectp(a:val)
      return a:val['#tag'][0][1:-1]
    elseif timl#keywordp(a:val)
      return 'timl.lang/Keyword'
    endif
  endif
  return type
endfunction

function! timl#satisfiesp(proto, obj)
  let t = g:[tr(timl#type(a:obj), '/.-', '##_')]
  return has_key(get(t, 'implements', {}), a:proto)
endfunction

function! timl#dispatch(proto, fn, obj, ...)
  let t = g:[tr(timl#type(a:obj), '/.-', '##_')]
  try
    let F = t.implements[a:proto][a:fn]
  catch /^Vim(let):E716:/
    throw "timl:E117: ".timl#type(a:obj)." doesn't implement ".a:proto
  endtry
  return timl#call(F, [a:obj] + a:000)
endfunction

function! timl#persistentb(val) abort
  let val = a:val
  if islocked('val')
    throw "timl: persistent! called on an already persistent value"
  else
    lockvar 1 val
    return val
  endif
endfunction

function! timl#transient(val) abort
  let val = a:val
  if islocked('val')
    return copy(val)
  else
    throw "timl: transient called on an already transient value"
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
    while !empty(_.val)
      let acc .= timl#str(timl#first(_.val)) . ','
      let _.val = timl#next(_.val)
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

runtime! autoload/timl/lang.vim
runtime! autoload/timl/vim.vim

" }}}1
" Section: Collections {{{1

function! timl#empty(coll) abort
  if timl#satisfiesp('timl.lang/IPersistentCollection', a:coll)
    return timl#dispatch('timl.lang/IPersistentCollection', 'empty', a:coll)
  else
    return g:timl#nil
  endif
endfunction

function! timl#conj(coll, x, ...) abort
  let t = timl#type(a:coll)
  if a:coll is g:timl#nil
    return timl#cons(a:coll, g:timl#nil)
  elseif t ==# 'timl.vim/List'
    return timl#persistentb(extend(timl#transient(a:coll), [a:x] + a:000))
  elseif t ==# 'timl.lang/HashSet'
    let coll = timl#transient(a:coll)
    let coll[timl#key(a:x)] = a:x
    let _ = {}
    for _.v in a:000
      let coll[timl#key(_.v)] = _.v
    endfor
    return timl#persistentb(coll)
  elseif t ==# 'timl.lang/HashMap' || t ==# 'timl.vim/Dictionary'
    let coll = timl#transient(a:coll)
    let _ = {}
    for _.v in a:000
      call timl#assocb(a:coll, timl#vec(_.v))
    endfor
    return timl#persistentb(coll)
  else
    let _ = {'coll': a:coll}
    for x in [a:x] + a:000
      let _.coll = timl#dispatch('timl.lang/IPersistentCollection', 'cons', _.coll, a:x)
    endfor
    return _.coll
  endif
endfunction

function! timl#count(seq) abort
  let l:count = 0
  let _ = {'seq': a:seq}
  while _.seq isnot# g:timl#nil && !timl#satisfiesp('timl.lang/Counted', _.seq)
    let l:count += 1
    let _.seq = timl#next(_.seq)
  endwhile
  return l:count + (_.seq is# g:timl#nil ? 0 : timl#dispatch('timl.lang/Counted', 'count', _.seq))
endfunction

function! timl#containsp(coll, val) abort
  let sentinel = {}
  return timl#get(a:coll, a:val, sentinel) isnot# sentinel
endfunction

function! timl#mapp(coll)
  return timl#type(a:coll) == 'timl.lang/HashMap'
endfunction

function! timl#setp(coll)
  return timl#type(a:coll) == 'timl.lang/HashSet'
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

let s:hash_map = timl#intern_type('timl.lang/HashMap')
function! timl#hash_map(...) abort
  let keyvals = a:0 == 1 ? a:1 : a:000
  let dict = timl#assocb(timl#bless(s:hash_map), keyvals)
  return timl#persistentb(dict)
endfunction

let s:hash_set = timl#intern_type('timl.lang/HashSet')
function! timl#hash_set(...) abort
  return timl#set(a:000)
endfunction

function! timl#set(coll) abort
  let dict = timl#bless(s:hash_set)
  if type(a:coll) == type([])
    let _ = {}
    for _.val in a:coll
      let dict[timl#key(_.val)] = _.val
    endfor
    return timl#persistentb(dict)
  else
    throw 'not implemented'
  endif
endfunction

function! timl#assocb(coll, ...) abort
  let keyvals = a:0 == 1 ? timl#vec(a:1) : a:000
  if len(keyvals) % 2 == 0
    let type = timl#type(a:coll)
    for i in range(0, len(keyvals) - 1, 2)
      let key = (type == 'timl.vim/Dictionary' ? timl#str(keyvals[i]) : timl#key(keyvals[i]))
      let a:coll[key] = keyvals[i+1]
    endfor
    return a:coll
  endif
  throw 'timl: more keys than values'
endfunction

function! timl#assoc(coll, ...) abort
  let keyvals = a:0 == 1 ? a:1 : a:000
  let coll = timl#transient(a:coll)
  call timl#assocb(coll, keyvals)
  return timl#persistentb(coll)
endfunction

function! timl#dissocb(coll, ...) abort
  let _ = {}
  let t = timl#type(a:coll)
  for _.key in a:000
    let key = (t == 'timl.vim/Dictionary' ? timl#str(_.key) : timl#key(_.key))
    if has_key(a:coll, key)
      call remove(a:coll, key)
    endif
  endfor
  return a:coll
endfunction

function! timl#dissoc(coll, ...) abort
  return timl#persistentb(call('timl#dissocb', [timl#transient(a:coll)] + a:000))
endfunction

" }}}1
" Section: Lists {{{1

let s:cons = timl#intern_type('timl.lang/Cons')

let s:ary = type([])

function! timl#seq(coll) abort
  let seq = timl#dispatch("timl.lang/Seqable", "seq", a:coll)
  return empty(seq) ? g:timl#nil : seq
endfunction

function! timl#first(coll) abort
  return timl#consp(a:coll) ? a:coll.car :
        \ type(a:coll) == s:ary ? get(a:coll, 0, g:timl#nil) :
        \ timl#dispatch('timl.lang/ISeq', 'first', timl#seq(a:coll))
endfunction

function! timl#rest(coll) abort
  return timl#consp(a:coll) ? a:coll.cdr :
        \ timl#dispatch('timl.lang/ISeq', 'rest', timl#seq(a:coll))
endfunction

function! timl#next(coll) abort
  let rest = timl#rest(a:coll)
  return timl#seq(rest)
endfunction

function! timl#get(coll, key, ...) abort
  if a:0
    return timl#dispatch('timl.lang/ILookup', 'get', a:coll, a:key, a:1)
  else
    return timl#dispatch('timl.lang/ILookup', 'get', a:coll, a:key)
  endif
endfunction

function! timl#consp(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '#tag') is# s:cons
endfunction

function! timl#list(...) abort
  return timl#list2(a:000)
endfunction

function! timl#cons(car, cdr) abort
  if timl#satisfiesp('timl.lang/Seqable', a:cdr)
    let cons = timl#bless(s:cons, {'car': a:car, 'cdr': a:cdr})
    return timl#persistentb(cons)
  endif
  throw 'timl: not seqable'
endfunction

function! timl#list2(array)
  let _ = {'cdr': g:timl#nil}
  for i in range(len(a:array)-1, 0, -1)
    let _.cdr = timl#cons(a:array[i], _.cdr)
  endfor
  return _.cdr
endfunction

function! timl#vec(coll)
  if type(a:coll) ==# s:ary
    return a:coll is# g:timl#nil ? [] : a:coll
  endif
  let array = []
  let _ = {'seq': a:coll}
  while !empty(_.seq)
    call add(array, timl#first(_.seq))
    let _.seq = timl#rest(_.seq)
  endwhile
  return timl#persistentb(extend(array, _.seq))
endfunction

function! timl#vectorp(obj) abort
  return type(a:obj) == type([]) && a:obj isnot# g:timl#nil
endfunction

" }}}1
" Section: Namespaces {{{1

let s:ns = timl#intern_type('timl.lang/Namespace')

function! timl#find_ns(name)
  return get(g:timl#namespaces, timl#name(a:name), g:timl#nil)
endfunction

function! timl#the_ns(name)
  if timl#type(a:name) ==# 'timl.lang/Namespace'
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
    let g:timl#namespaces[a:name] = timl#bless(s:ns, {'name': name, 'referring': [], 'aliases': {}})
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

" }}}1
" Section: Eval {{{1

function! timl#call(Func, args, ...) abort
  if type(a:Func) == type(function('tr'))
    return call(a:Func, a:args, a:0 ? a:1 : {})
  elseif timl#functionp(a:Func)
    return call(a:Func.call, (a:0 ? [a:1] : []) + a:args, a:Func)
  else
    return call('timl#dispatch', ['timl.lang/IFn', 'invoke', a:Func] + (a:0 ? [a:1] : []) + a:args)
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
  return substitute(tr(fnamemodify(path, ':r:r'), '\/_', '..-'), '^\%(autoload\|plugin\|test\).', '', '')
endfunction

function! timl#ns_for_cursor(...) abort
  let pattern = '\c(\%(in-\)\=ns\s\+''\=[[:alpha:]]\@='
  let line = 0
  if !a:0 || a:1
    let line = search(pattern, 'bcnW')
  endif
  if !line
    let i = 1
    while i < line('$') && i < 100
      if getline(i) =~# pattern
        let line = i
        break
      endif
      let i += 1
    endwhile
  endif
  if line
    let ns = matchstr(getline(line), pattern.'\zs[[:alnum:]._-]\+')
  else
    let ns = timl#ns_for_file(expand('%:p'))
  endif
  if has_key(g:timl#namespaces, ns)
    return ns
  else
    return 'user'
  endif
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
  let ns = timl#str(a:ns)
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
