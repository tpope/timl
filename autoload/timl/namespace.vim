" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_namespace")
  finish
endif
let g:autoloaded_timl_namespace = 1

let s:type = timl#type#intern('timl.lang/Namespace')

if !exists('g:timl#namespaces')
  let g:timl#namespaces = {}
endif

function! timl#namespace#create(name) abort
  let name = timl#symbol#coerce(a:name)
  if !has_key(g:timl#namespaces, name[0])
    let g:timl#namespaces[name[0]] = timl#bless(s:type, {'name': name, 'referring': [], 'aliases': {}, 'mappings': {}})
  endif
  let ns = g:timl#namespaces[name[0]]
  return ns
endfunction

function! timl#namespace#name(ns) abort
  return a:ns.name
endfunction

function! timl#namespace#select(name) abort
  let g:timl#core#_STAR_ns_STAR_ = timl#namespace#create(a:name)
  return g:timl#core#_STAR_ns_STAR_
endfunction

function! timl#namespace#refer(name) abort
  let me = g:timl#core#_STAR_ns_STAR_
  let sym = timl#symbol#coerce(a:name)
  if sym isnot# me.name && index(me.referring, sym) < 0
    call insert(me.referring, sym)
  endif
  call extend(me.mappings, timl#namespace#find(sym).mappings)
  return g:timl#nil
endfunction

function! timl#namespace#use(name) abort
  call timl#require(a:name)
  return timl#namespace#refer(a:name)
endfunction

function! timl#namespace#alias(alias, name) abort
  let me = g:timl#core#_STAR_ns_STAR_
  let me.aliases[timl#str(a:alias)] = a:name
  return g:timl#nil
endfunction

function! timl#namespace#find(name) abort
  return get(g:timl#namespaces, timl#str(a:name), g:timl#nil)
endfunction

function! timl#namespace#the(name) abort
  if timl#type#string(a:name) ==# 'timl.lang/Namespace'
    return a:name
  endif
  let name = timl#str(a:name)
  if has_key(g:timl#namespaces, name)
    return g:timl#namespaces[name]
  endif
  throw 'timl: no such namespace '.name
endfunction

function! timl#namespace#maybe_resolve(ns, sym, ...)
  let ns = timl#namespace#the(a:ns)
  let sym = timl#symbol#coerce(a:sym)
  if has_key(ns.mappings, sym.str)
    return ns.mappings[sym.str]
  endif
  if !empty(sym.namespace)
    if has_key(ns.aliases, sym.namespace)
      let aliasns = timl#namespace#the(ns.aliases[sym.namespace])
      if has_key(aliasns.mappings, sym.name)
        return aliasns.mappings[sym.name]
      endif
    endif
    if has_key(g:timl#namespaces, sym.namespace) && has_key(g:timl#namespaces[sym.namespace].mappings, sym.name)
      return g:timl#namespaces[sym.namespace].mappings[sym.name]
    endif
  endif
  return a:0 ? a:1 : g:timl#nil
endfunction

function! timl#namespace#intern(ns, name, ...)
  let ns = timl#namespace#the(a:ns)
  let str = ns.name[0].'/'.timl#symbol#coerce(a:name)[0]
  let munged = timl#munge(str)
  let var = timl#bless('timl.lang/Var', {'name': a:name, 'ns': ns, 'str': str, 'munged': munged, 'meta': get(a:name, 'meta', g:timl#nil)})
  if a:0
    unlet! g:{munged}
    let g:{munged} = a:1
  elseif !exists('g:'.munged)
    let g:{munged} = g:timl#nil
  endif
  let ns.mappings[a:name[0]] = var
  return a:0 ? a:1 : g:timl#nil
endfunction

function! timl#namespace#all()
  return timl#seq(values(g:timl#namespaces))
endfunction
