" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_namespace")
  finish
endif
let g:autoloaded_timl_namespace = 1

if !exists('g:timl#namespaces')
  let g:timl#namespaces = {}
endif

function! timl#namespace#munge(str) abort
  return tr(a:str, '-.', '_#')
endfunction

function! timl#namespace#create(name) abort
  let name = timl#symbol#cast(a:name)
  if !has_key(g:timl#namespaces, name[0])
    let ns = timl#type#bless(s:type, {'__name__': name, '__aliases__': {}, '__mappings__': {}})
    let g:timl#namespaces[name[0]] = ns
    let g:{timl#namespace#munge(name[0])} = ns
  endif
  return g:timl#namespaces[name[0]]
endfunction

function! timl#namespace#name(ns) abort
  return timl#namespace#the(a:ns).__name__
endfunction

function! timl#namespace#map(ns) abort
  return timl#namespace#the(a:ns).__mappings__
endfunction

function! timl#namespace#aliases(ns) abort
  return timl#namespace#the(a:ns).__aliases__
endfunction

function! timl#namespace#select(name) abort
  let g:timl#core._STAR_ns_STAR_ = timl#namespace#create(a:name)
  return g:timl#core._STAR_ns_STAR_
endfunction

function! timl#namespace#refer(name, ...) abort
  let me = g:timl#core._STAR_ns_STAR_
  let sym = timl#symbol#cast(a:name)
  let ns = timl#namespace#find(sym)
  let i = 0
  let only = keys(ns.__mappings__)
  let exclude = []
  if !exists('s:k_only')
    let s:k_only = timl#keyword#intern('only')
    let s:k_exclude = timl#keyword#intern('exclude')
  endif
  while i < a:0
    if a:000[i] is# s:k_only
      let only = map(copy(timl#array#coerce(get(a:000, i+1, []))), 'timl#symbol#cast(v:val).name')
      let i += 2
    elseif a:000[i] is# s:k_exclude
      let exclude = map(copy(timl#array#coerce(get(a:000, i+1, []))), 'timl#symbol#cast(v:val).name')
      let i += 2
    elseif timl#keyword#test(a:000[i])
      throw 'timl#namespace: invalid option :'.a:000[i][0]
    else
      throw 'timl#namespace: invalid option type '.timl#type#string(a:000[i][0])
    endif
  endwhile
  let _ = {}
  for name in only
    if !has_key(ns.__mappings__, name)
      throw 'timl#namespace: no such mapping '.name
    endif
    let var = ns.__mappings__[name]
    let _.private = get(var.meta, 'private', g:timl#nil)
    if var.ns is# ns && (_.private is# g:timl#false || _.private is# g:timl#nil) && index(exclude, name) == -1
      let me.__mappings__[name] = var
    endif
  endfor
  return g:timl#nil
endfunction

function! timl#namespace#alias(alias, name) abort
  let me = g:timl#core._STAR_ns_STAR_
  let me.__aliases__[timl#symbol#cast(a:alias).name] = a:name
  return g:timl#nil
endfunction

function! timl#namespace#find(name) abort
  return get(g:timl#namespaces, type(a:name) == type('') ? a:name : a:name.name, g:timl#nil)
endfunction

function! timl#namespace#the(name) abort
  if timl#type#string(a:name) ==# s:type.str
    return a:name
  endif
  let name = type(a:name) == type('') ? a:name : a:name.name
  if has_key(g:timl#namespaces, name)
    return g:timl#namespaces[name]
  endif
  throw 'timl: no such namespace '.name
endfunction

function! timl#namespace#maybe_resolve(ns, sym, ...) abort
  let ns = timl#namespace#the(a:ns)
  let sym = timl#symbol#cast(a:sym)
  if has_key(ns.__mappings__, sym.str)
    return ns.__mappings__[sym.str]
  endif
  if !empty(sym.namespace)
    if has_key(ns.__aliases__, sym.namespace)
      let aliasns = timl#namespace#the(ns.__aliases__[sym.namespace])
      if has_key(aliasns.__mappings__, sym.name)
        return aliasns.__mappings__[sym.name]
      endif
    endif
    if has_key(g:timl#namespaces, sym.namespace) && has_key(g:timl#namespaces[sym.namespace].__mappings__, sym.name)
      return g:timl#namespaces[sym.namespace].__mappings__[sym.name]
    endif
  endif
  return a:0 ? a:1 : g:timl#nil
endfunction

function! timl#namespace#all() abort
  return timl#coll#seq(values(g:timl#namespaces))
endfunction

function! timl#namespace#intern(ns, name, ...) abort
  let ns = timl#namespace#the(a:ns)
  let nsname = timl#namespace#name(ns).str
  let str = nsname.'/'.timl#symbol#cast(a:name).str
  let nsglobal = timl#namespace#munge(nsname)
  let key = timl#var#munge(a:name.str)
  let meta = copy(a:name.meta is# g:timl#nil ? timl#map#create([]) : a:name.meta)
  let meta.name = a:name
  let meta.ns = ns
  lockvar 1 meta
  if has_key(ns.__mappings__, a:name[0]) && ns.__mappings__[a:name[0]].ns is# ns
    let var = ns.__mappings__[a:name[0]]
    let var.meta = meta
  else
    let var = timl#type#bless(s:var_type, {'ns': ns, 'str': str, 'funcname': nsglobal.'#'.key, 'location': 'g:'.nsglobal.'.'.key, 'meta': meta})
  endif
  if a:0
    let ns[key] = a:1
  elseif !has_key(ns, key)
    let ns[key] = g:timl#nil
  endif
  let ns.__mappings__[a:name[0]] = var
  return var
endfunction

let s:type = timl#type#core_create('Namespace')
let s:var_type = timl#type#core_create('Var')

call timl#type#core_define('Type', g:timl#nil, {})
call timl#type#core_define('Namespace', g:timl#nil, {})
call timl#type#core_define('Var', g:timl#nil, {
      \ 'hash': 'timl#hash#str_attribute',
      \ 'get-meta': 'timl#meta#from_attribute',
      \ 'reset-meta!': 'timl#var#reset_meta',
      \ 'call': 'timl#var#call',
      \ 'funcref': 'timl#var#funcref',
      \ 'deref': 'timl#var#get'})
call timl#type#core_define('Symbol', g:timl#nil, {
      \ 'get-meta': 'timl#meta#from_attribute',
      \ 'with-meta': 'timl#meta#copy_assign_lock',
      \ 'equiv': 'timl#symbol#equal',
      \ 'hash': 'timl#hash#str_attribute',
      \ 'to-string': 'timl#keyword#to_string',
      \ 'name': 'timl#keyword#name',
      \ 'namespace': 'timl#keyword#namespace',
      \ 'call': 'timl#keyword#call'})
call timl#type#core_define('Keyword', g:timl#nil, {
      \ 'to-string': 'timl#keyword#to_string',
      \ 'hash': 'timl#hash#str_attribute',
      \ 'name': 'timl#keyword#name',
      \ 'namespace': 'timl#keyword#namespace',
      \ 'call': 'timl#keyword#call'})
