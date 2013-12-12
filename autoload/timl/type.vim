" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_type")
  finish
endif
let g:autoloaded_timl_type = 1

" Section: Blessing

if !exists('g:timl_tag_sentinel')
  let g:timl_tag_sentinel = timl#freeze('tagged')
endif

function! timl#type#intern(type)
  return timl#keyword('#'.a:type)
endfunction

let s:types = {
      \ 0: 'timl.vim/Number',
      \ 1: 'timl.vim/String',
      \ 2: 'timl.vim/Funcref',
      \ 3: 'timl.vim/List',
      \ 4: 'timl.vim/Dictionary',
      \ 5: 'timl.vim/Float'}

function! timl#type#objectp(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '#tagged') is g:timl_tag_sentinel
endfunction

function! timl#type#string(val) abort
  let type = get(s:types, type(a:val), 'timl.vim/Unknown')
  if type ==# 'timl.vim/List' && a:val is# g:timl#nil
    return 'timl.lang/Nil'
  elseif type == 'timl.vim/Dictionary'
    if get(a:val, '#tagged') is g:timl_tag_sentinel
      return a:val['#tag'][0][1:-1]
    elseif timl#keywordp(a:val)
      return 'timl.lang/Keyword'
    endif
  endif
  return type
endfunction

function! timl#type#bless(class, ...) abort
  let obj = a:0 ? a:1 : {}
  let obj['#tagged'] = g:timl_tag_sentinel
  let obj['#tag'] = type(a:class) == type('') ? timl#keyword('#'.a:class) : a:class
  return obj
endfunction

" Section: Hierarchy
" Cribbed from clojure.core

function! timl#type#parents(key)
  return timl#set(values(get(g:timl_hierarchy.parents, timl#str(a:key), {})))
endfunction

function! timl#type#ancestors(key)
  return timl#set(values(get(g:timl_hierarchy.ancestors, timl#str(a:key), {})))
endfunction

function! timl#type#descendants(key)
  return timl#set(values(get(g:timl_hierarchy.descendants, timl#str(a:key), {})))
endfunction

function! s:tf(m, source, sources, target, targets)
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

function! s:isap(tag, parent)
  return a:tag ==# a:parent || has_key(get(g:timl_hierarchy.ancestors, a:tag, {}), a:parent)
endfunction

function! timl#type#isap(tag, parent)
  return timl#kw(a:tag) is# timl#kw(a:parent) || has_key(get(g:timl_hierarchy.ancestors, a:tag[0], {}), a:parent[0])
endfunction

function! timl#type#derive(tag, parent)
  let tp = g:timl_hierarchy.parents
  let td = g:timl_hierarchy.descendants
  let ta = g:timl_hierarchy.ancestors
  let tag = timl#kw(a:tag)
  let parent = timl#kw(a:parent)
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

function! timl#type#canp(obj, this)
  return s:get_method(a:this, timl#type(a:obj)) isnot# g:timl#nil
endfunction

function! s:get_method(this, type)
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
      let a:this.cache[a:type] = get(a:this.methods, timl#key(g:timl#nil), g:timl#nil)
    else
      let a:this.cache[a:type] = _.preferred[1]
    endif
  endif
  return get(a:this.cache, a:type, g:timl#nil)
endfunction

function! timl#type#dispatch(this, ...) abort
  let type = timl#type#string(a:1)
  if a:this.hierarchy isnot# g:timl_hierarchy
    let a:this.cache = {}
    let a:this.hierarchy = g:timl_hierarchy
  endif
  if has_key(a:this.cache, type)
    let Dispatch = a:this.cache[type]
  else
    let Dispatch = s:get_method(a:this, type)
  endif
  if Dispatch isnot# g:timl#nil
    return timl#call(Dispatch, a:000)
  endif
  throw 'timl#type: no '.a:this.ns.name[0].'/'.a:this.name[0].' dispatch for '.type
endfunction

" Section: Method Creation

function! timl#type#define_method(ns, name, type, fn) abort
  let munged = timl#munge(a:ns.'#'.a:name)
  if !exists('g:'.munged) || timl#type#string(g:{munged}) isnot# 'timl.lang/MultiFn'
    unlet! g:{munged}
    let g:{munged} = timl#bless('timl.lang/MultiFn', {
          \ 'ns': g:timl#namespaces[a:ns],
          \ 'name': timl#symbol(a:name),
          \ 'cache': {},
          \ 'hierarchy': g:timl_hierarchy,
          \ 'methods': {}})
  endif
  let multi = g:{munged}
  let multi.methods[a:type is# g:timl#nil ? ' ' : timl#str(a:type)] = a:fn
  let multi.cache = {}
  return multi
endfunction

" Section: Initialization

if !exists('g:timl_hierarchy')
  let g:timl_hierarchy = {'parents': timl#bless('timl.lang/HashMap'), 'descendants': timl#bless('timl.lang/HashMap'), 'ancestors': timl#bless('timl.lang/HashMap')}
  call timl#type#derive(timl#keyword('timl.vim/Number'), timl#keyword('timl.vim/Numeric'))
  call timl#type#derive(timl#keyword('timl.vim/Float'), timl#keyword('timl.vim/Numeric'))
endif

" vim:set et sw=2:
