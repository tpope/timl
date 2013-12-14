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

function! timl#freeze(...) abort
  return a:000
endfunction

function! timl#truth(val) abort
  return a:val isnot# g:timl#nil && a:val isnot# g:timl#false
endfunction

function! timl#identity(x) abort
  return a:x
endfunction

function! timl#key(key)
  if type(a:key) == type(0)
    return string(a:key)
  elseif timl#keyword#test(a:key)
    return a:key[0]
  elseif a:key is# g:timl#nil
    return ' '
  else
    return ' '.timl#printer#string(a:key)
  endif
endfunction

function! timl#dekey(key)
  if a:key =~# '^#'
    throw 'timl: invalid key '.a:key
  elseif a:key ==# ' '
    return g:timl#nil
  elseif a:key =~# '^ '
    return timl#reader#read_string(a:key[1:-1])
  elseif a:key =~# '^[-+]\=\d'
    return timl#reader#read_string(a:key)
  else
    return timl#keyword(a:key)
  endif
endfunction

" }}}1
" Section: Munging {{{1

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

" }}}1
" Section: Keywords {{{1

function! timl#keyword(str)
  return timl#keyword#intern(a:str)
endfunction

" }}}1
" Section: Type System {{{1

function! timl#bless(class, ...) abort
  return timl#type#bless(a:class, a:0 ? a:1 : {})
endfunction

if !exists('g:timl#nil')
  let g:timl#nil = timl#freeze()
  lockvar 1 g:timl#nil
endif

function! timl#type(val) abort
  return timl#type#string(a:val)
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

function! timl#meta(obj) abort
  if timl#type#objectp(a:obj)
    return get(a:obj, '#meta', g:timl#nil)
  endif
  return g:timl#nil
endfunction

function! timl#with_meta(obj, meta) abort
  if timl#type#objectp(a:obj)
    if !timl#equalp(get(a:obj, '#meta', g:timl#nil), a:meta)
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
  throw 'timl: cannot attach metadata to a '.timl#type#string(a:obj)
endfunction

function! timl#str(val) abort
  if type(a:val) == type('')
    return a:val
  elseif type(a:val) == type(function('tr'))
    return substitute(join([a:val]), '[{}]', '', 'g')
  elseif timl#symbol#test(a:val) || timl#keyword#test(a:val)
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

function! timl#equalp(x, ...) abort
  for y in a:000
    if type(a:x) != type(y) || a:x !=# y
      return 0
    endif
  endfor
  return 1
endfunction

" }}}1
" Section: Symbols {{{1

let s:symbol = timl#keyword('#timl.lang/Symbol')
function! timl#symbol(str)
  return timl#symbol#intern(a:str)
endfunction

function! timl#gensym(...)
  let s:id = get(s:, 'id', 0) + 1
  return timl#symbol((a:0 ? a:1 : 'G__').s:id)
endfunction

runtime! autoload/timl/lang.vim

" }}}1
" Section: Collections {{{1

function! timl#collp(coll) abort
  return timl#type#canp(a:coll, g:timl#core#conj)
endfunction

function! timl#into(coll, seq) abort
  let t = timl#type#string(a:coll)
  if timl#type#canp(a:coll, g:timl#core#transient)
    let _ = {'coll': timl#type#dispatch(g:timl#core#transient, a:coll), 'seq': timl#seq(a:seq)}
    while _.seq isnot# g:timl#nil
      let _.coll = timl#type#dispatch(g:timl#core#conj_BANG_, _.coll, timl#first(_.seq))
      let _.seq = timl#next(_.seq)
    endfor
    return timl#type#dispatch(g:timl#core#persistent_BANG_, _.coll)
  else
    let _ = {'coll': a:coll, 'seq': timl#seq(a:seq)}
    while _.seq isnot# g:timl#nil
      let _.coll = timl#type#dispatch(g:timl#core#conj, _.coll, timl#first(_.seq))
      let _.seq = timl#next(_.seq)
    endfor
    return _.coll
  endif
endfunction

function! timl#count(counted) abort
  return timl#type#dispatch(g:timl#core#count, a:counted)
endfunction

function! timl#containsp(coll, val) abort
  let sentinel = {}
  return timl#get(a:coll, a:val, sentinel) isnot# sentinel
endfunction

function! timl#mapp(coll)
  return timl#type#canp(a:coll, g:timl#core#dissoc)
endfunction

function! timl#setp(coll)
  return timl#type#canp(a:coll, g:timl#core#disj)
endfunction

function! timl#dictp(coll)
  return timl#type#string(a:coll) ==# 'vim/Dictionary'
endfunction

function! timl#set(seq) abort
  return timl#set#coerce(a:seq)
endfunction

" }}}1
" Section: Lists {{{1

let s:cons = timl#type#intern('timl.lang/Cons')

let s:ary = type([])

function! timl#seq(coll) abort
  return timl#type#dispatch(g:timl#core#seq, a:coll)
endfunction

function! timl#seqp(coll) abort
  return timl#type#canp(a:coll, g:timl#core#seq)
endfunction

function! timl#first(coll) abort
  if timl#consp(a:coll)
    return a:coll.car
  elseif type(a:coll) == s:ary
    return get(a:coll, 0, g:timl#nil)
  else
    return timl#type#dispatch(g:timl#core#first, a:coll)
  endif
endfunction

function! timl#rest(coll) abort
  if timl#consp(a:coll)
    return a:coll.cdr
  elseif timl#type#canp(a:coll, g:timl#core#more)
    return timl#type#dispatch(g:timl#core#more, a:coll)
  else
    return timl#type#dispatch(g:timl#core#more, timl#seq(a:coll))
  endif
endfunction

function! timl#next(coll) abort
  let rest = timl#rest(a:coll)
  return timl#seq(rest)
endfunction

function! timl#ffirst(seq) abort
  return timl#first(timl#first(a:seq))
endfunction

function! timl#fnext(seq) abort
  return timl#first(timl#next(a:seq))
endfunction

function! timl#nfirst(seq) abort
  return timl#next(timl#first(a:seq))
endfunction

function! timl#nnext(seq) abort
  return timl#next(timl#next(a:seq))
endfunction

function! timl#get(coll, key, ...) abort
  return timl#type#dispatch(g:timl#core#lookup, a:coll, a:key, a:0 ? a:1 : g:timl#nil)
endfunction

function! timl#consp(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '#tag') is# s:cons
endfunction

function! timl#list(...) abort
  return timl#list2(a:000)
endfunction

function! timl#list2(array)
  let _ = {'cdr': g:timl#empty_list}
  for i in range(len(a:array)-1, 0, -1)
    let _.cdr = timl#cons#create(a:array[i], _.cdr)
  endfor
  return _.cdr
endfunction

function! timl#ary(coll) abort
  return timl#array#coerce(a:coll)
endfunction

function! timl#vec(coll) abort
  if type(a:coll) == type([])
    let vec = copy(a:coll)
  else
    let vec = timl#array#coerce(a:coll)
  endif
  return timl#array#lock(vec)
endfunction

function! timl#vector(...) abort
  return timl#vec(a:000)
endfunction

function! timl#vectorp(obj) abort
  return type(a:obj) == type([]) && a:obj isnot# g:timl#nil
endfunction

" }}}1
" Section: Eval {{{1

let s:function_tag = timl#keyword('#timl.lang/Function')
let s:multifn_tag = timl#keyword('#timl.lang/MultiFn')
function! timl#call(Func, args, ...) abort
  if type(a:Func) == type(function('tr'))
    return call(a:Func, a:args, a:0 ? a:1 : {})
  elseif type(a:Func) == type({}) && get(a:Func, '#tag') is# s:function_tag
    if !has_key(a:Func, 'apply')
      let g:FFF = a:Func
      TLinspect a:Func
    endif
    return a:Func.apply(a:args)
  elseif type(a:Func) == type({}) && get(a:Func, '#tag') is# s:multifn_tag
    return call('timl#type#dispatch', [a:Func] + a:args)
  else
    return call('timl#type#dispatch', [g:timl#core#_invoke, a:Func] + (a:0 ? [a:1] : []) + a:args)
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
  if !exists('g:autoloaded_timl_compiler')
    runtime! autoload/timl/compiler.vim
  endif
  let nsobj = timl#namespace#find(timl#symbol(ns))
  if nsobj isnot# g:timl#nil
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
    call add(dict.qflist, {"filename": matchstr(a:throwpoint, '^.\{-\}\ze\.\.')})
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

function! timl#load(path) abort
  if !empty(findfile('autoload/'.a:path.'.vim', &rtp))
    execute 'runtime! autoload/'.a:path.'.vim'
    return g:timl#nil
  endif
  for file in findfile('autoload/'.a:path.'.tim', &rtp, -1)
    call timl#source_file(file)
    return g:timl#nil
  endfor
  throw 'timl: could not load '.a:path
endfunction

function! timl#load_all_relative(paths)
  for path in timl#array#coerce(a:paths)
    if path[0] ==# '/'
      let path = path[1:-1]
    else
      let path = substitute(tr(g:timl#core#_STAR_ns_STAR_.name[0], '.-', '/_'), '[^/]*$', '', '') . path
    endif
    call timl#load(path)
  endfor
  return g:timl#nil
endfunction

if !exists('g:timl#requires')
  let g:timl#requires = {}
endif

function! timl#require(ns) abort
  let ns = timl#str(a:ns)
  if !has_key(g:timl#requires, ns)
    call timl#load(tr(ns, '.-', '/_'))
    let g:timl#requires[ns] = 1
  endif
  return g:timl#nil
endfunction

" }}}1

" vim:set et sw=2:
