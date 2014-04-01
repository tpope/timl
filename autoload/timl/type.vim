" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_type")
  finish
endif
let g:autoloaded_timl_type = 1

function! s:freeze(...) abort
  return a:000
endfunction

if !exists('g:timl#nil')
  let g:timl#nil = s:freeze()
  lockvar 1 g:timl#nil
endif

" Section: Blessing

if !exists('g:timl_tag_sentinel')
  let g:timl_tag_sentinel = s:freeze('blessed object')
  lockvar 1 g:timl_tag_sentinel
endif

if !exists('s:types')
  let s:types = {}
endif

function! timl#type#find(name) abort
  return get(s:types, timl#string#coerce(a:name), g:timl#nil)
endfunction

function! timl#type#create(name, ...) abort
  let munged = tr(a:name, '-./', '_##')
  if !has_key(s:types, a:name)
    let s:types[a:name] = timl#type#bless(s:type_type, {
          \ 'str': a:name,
          \ 'location': 'g:'.munged,
          \ 'slots': g:timl#nil,
          \ '__call__': function('timl#type#constructor')})
  endif
  let s:types[a:name].slots = a:0 ? a:1 : g:timl#nil
  let g:{munged} = s:types[a:name]
  return s:types[a:name]
endfunction

function! timl#type#core_create(name, ...) abort
  return timl#type#create('timl.lang/'.a:name, a:0 ? a:1 : g:timl#nil)
endfunction

function! timl#type#core_define(name, slots, methods) abort
  let ns = timl#namespace#create(timl#symbol#intern('timl.core'))
  let type = timl#type#core_create(a:name, a:slots)
  for [k, v] in items(a:methods)
    call timl#type#define_method(ns, timl#symbol#intern(k), type, function(v))
  endfor
  return type
endfunction

function! timl#type#constructor(_) dict abort
  if get(self, 'slots') is# g:timl#nil
    throw 'timl: constructor not implemented'
  endif
  if len(a:_) != len(self.slots)
    throw 'timl: arity error'
  endif
  let object = {}
  for i in range(len(a:_))
    let object[self.slots[i]] = a:_[i]
  endfor
  return timl#type#bless(self, object)
endfunction

if !has_key(s:types, 'timl.lang/Type')
  let s:types['timl.lang/Type'] = {
        \ 'str': 'timl.lang/Type',
        \ 'location': 'g:timl#lang#Type',
        \ 'slots': g:timl#nil,
        \ '__call__': function('timl#type#constructor')}
endif
let s:type_type = s:types['timl.lang/Type']
function! timl#type#define(ns, var, slots) abort
  let str = timl#namespace#name(a:ns).name . '/' . timl#symbol#cast(a:var).name
  let type = timl#type#create(str)
  if a:slots isnot# g:timl#nil
    let type.slots = map(timl#array#coerce(a:slots), 'timl#symbol#cast(v:val).name')
  endif
  return timl#namespace#intern(a:ns, a:var, type)
endfunction

let s:builtins = {
      \ 0: 'vim/Number',
      \ 1: 'vim/String',
      \ 2: 'vim/Funcref',
      \ 3: 'vim/List',
      \ 4: 'vim/Dictionary',
      \ 5: 'vim/Float'}

function! timl#type#objectp(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '__flag__') is g:timl_tag_sentinel
endfunction

function! timl#type#string(val) abort
  let type = get(s:builtins, type(a:val), 'vim/Unknown')
  if a:val is# g:timl#nil
    return 'timl.lang/Nil'
  elseif type ==# 'vim/Dictionary'
    if get(a:val, '__flag__') is g:timl_tag_sentinel
      return a:val.__type__.str
    endif
  endif
  return type
endfunction

let s:proto = {
      \ '__call__': function('timl#type#dispatch_call'),
      \ '__flag__': g:timl_tag_sentinel}
function! timl#type#bless(type, ...) abort
  let obj = a:0 ? a:1 : {}
  call extend(obj, s:proto, 'keep')
  let obj.__type__ = a:type
  return obj
endfunction

function! timl#type#dispatch_call(_) dict
  return g:timl#core.call.__call__([self, a:_])
endfunction

call timl#type#bless(s:type_type, s:type_type)

" Section: Hierarchy
" Cribbed from clojure.core

function! timl#type#parents(key) abort
  return timl#set#coerce(values(get(g:timl_hierarchy.parents, timl#string#coerce(a:key), {})))
endfunction

function! timl#type#ancestors(key) abort
  return timl#set#coerce(values(get(g:timl_hierarchy.ancestors, timl#string#coerce(a:key), {})))
endfunction

function! timl#type#descendants(key) abort
  return timl#set#coerce(values(get(g:timl_hierarchy.descendants, timl#string#coerce(a:key), {})))
endfunction

function! s:tf(m, source, sources, target, targets) abort
  for k in [a:source] + values(get(a:sources, a:source[0], {}))
    if !has_key(a:targets, k[0])
      let a:targets[k[0]] = {}
    endif
    let a:targets[k[0]][a:target[0]] = a:target
    for j in values(get(a:targets, a:target[0], {}))
      let a:targets[k[0]][j[0]] = j
    endfor
  endfor
endfunction

function! s:isap(tag, parent) abort
  return a:tag ==# a:parent || has_key(get(g:timl_hierarchy.ancestors, a:tag, {}), a:parent)
endfunction

function! timl#type#isap(tag, parent) abort
  return timl#keyword#cast(a:tag) is# timl#keyword#cast(a:parent)
        \ || has_key(get(g:timl_hierarchy.ancestors, a:tag[0], {}), a:parent[0])
endfunction

function! timl#type#derive(tag, parent) abort
  let tp = g:timl_hierarchy.parents
  let td = g:timl_hierarchy.descendants
  let ta = g:timl_hierarchy.ancestors
  let tag = timl#keyword#cast(a:tag)
  let parent = timl#keyword#cast(a:parent)
  if !has_key(tp, tag[0])
    let tp[tag[0]] = {}
  endif
  if !has_key(tp[tag[0]], parent[0])
    if has_key(get(ta, tag[0], {}), parent[0])
      throw "timl#type: :".tag[0]." already has :".parent[0]." as ancestor"
    endif
    if has_key(get(ta, parent[0], {}), tag[0])
      throw "timl#type: :".parent[0]." has :".tag[0]." as ancestor"
    endif
    let tp[tag[0]][parent[0]] = parent
    call s:tf(ta, tag, td, parent, ta)
    call s:tf(td, parent, ta, tag, td)
  endif
  let g:timl_hierarchy = copy(g:timl_hierarchy) " expire caches
  return g:timl_hierarchy
endfunction

" Section: Dispatch

function! timl#type#canp(obj, this) abort
  return s:get_method(a:this, timl#type#string(a:obj)) isnot# g:timl#nil
endfunction

function! s:get_method(this, type) abort
  if a:this.hierarchy isnot# g:timl_hierarchy
    let a:this.cache = {}
    let a:this.hierarchy = g:timl_hierarchy
  endif
  if !has_key(a:this.cache, a:type)
    let _ = {'preferred': g:timl#nil}
    for [_.type, _.fn] in items(a:this.methods)
      if s:isap(a:type, _.type)
        if _.preferred is g:timl#nil || s:isap(_.type, _.preferred[0])
          let _.preferred = [_.type, _.fn]
        elseif !s:isap(_.preferred[0], _.type)
          throw 'timl#type: ambiguous'
        endif
      endif
    endfor
    if _.preferred is# g:timl#nil
      let a:this.cache[a:type] = get(a:this.methods, ' ', g:timl#nil)
    else
      let a:this.cache[a:type] = _.preferred[1]
    endif
  endif
  return get(a:this.cache, a:type, g:timl#nil)
endfunction

let s:t_function = type(function('tr'))
let s:t_dict = type({})
function! timl#type#apply(_) dict abort
  let type = timl#type#string(a:_[0])
  if self.hierarchy isnot# g:timl_hierarchy
    let self.cache = {}
    let self.hierarchy = g:timl_hierarchy
  endif
  let Dispatch = has_key(self.cache, type) ? self.cache[type] : s:get_method(self, type)
  let t = type(Dispatch)
  if t == s:t_function
    return call(Dispatch, a:_)
  elseif t == s:t_dict
    return Dispatch.__call__(a:_)
  endif
  throw 'timl#type: no '.self.ns.__name__[0].'/'.self.name[0].' dispatch for '.type
endfunction

function! timl#type#dispatch(this, _) abort
  return call('timl#type#apply', [a:_], a:this)
endfunction

" Section: Method Creation

function! timl#type#define_method(ns, name, type, fn) abort
  let var = timl#namespace#maybe_resolve(a:ns, timl#symbol#cast(a:name))
  if var is# g:timl#nil || timl#type#string(timl#var#get(var)) isnot# 'timl.lang/MultiFn'
    unlet var
    if !empty(a:name.namespace)
      throw "timl: no such method ".a:name.str
    endif
    let fn = timl#type#bless(s:multifn_type, {
          \ '__call__': function('timl#type#apply'),
          \ 'ns': a:ns,
          \ 'name': a:name,
          \ 'cache': {},
          \ 'hierarchy': g:timl_hierarchy,
          \ 'methods': {}})
    let var = timl#namespace#intern(a:ns, a:name, fn)
  endif
  let multi = timl#var#get(var)
  let multi.methods[a:type is# g:timl#nil ? ' ' : a:type.str] = a:fn
  let multi.cache = {}
  return var
endfunction
let s:multifn_type = timl#type#core_create('MultiFn')

" Section: Initialization

if !exists('g:timl_hierarchy')
  let g:timl_hierarchy = {'parents': {}, 'descendants': {}, 'ancestors': {}}
endif

" vim:set et sw=2:
