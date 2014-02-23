" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_hash')
  finish
endif
let g:autoloaded_timl_hash = 1

function! timl#hash#compute(obj) abort
  if type(a:obj) == type('')
    let hash = timl#hash#string(a:obj)
  elseif type(a:obj) == type(0)
    let hash = a:obj
  elseif timl#type#canp(a:obj, g:timl#core.hash)
    let hash = timl#invoke(g:timl#core.hash, a:obj)
  elseif timl#type#canp(a:obj, g:timl#core.seq)
    let hash = timl#hash#sequential(a:obj)
  else
    let hash = timl#invoke(g:timl#core.hash, a:obj)
  endif
  if exists('hash')
    let hash = hash % 0x40000000
    if hash < 0
      let hash += 0x40000000
    endif
    return hash
  endif
endfunction

function! timl#hash#string(str) abort
  let r = 0
  let l = len(a:str)
  let i = 0
  while i < l
    let r = 31 * r + char2nr(a:str[i])
    let i += 1
  endwhile
  return r
endfunction

function! timl#hash#str_attribute(obj) abort
  return timl#hash#string(a:obj.str)
endfunction

function! timl#hash#sequential(s) abort
  let r = 0
  let _ = {'seq': timl#coll#seq(a:s)}
  while _.seq isnot# g:timl#nil
    let r += timl#hash#compute(timl#coll#first(a:s))
    let _.seq = timl#coll#next(_.seq)
  endwhile
  return r
endfunction

let s:idx = '0123456789abcdefghijklmnopqrstuv'
function! s:idx_for(hash, level) abort
  return s:idx[(a:hash/a:level) % 32]
endfunction

function! timl#hash#find(node, key) abort
  let hash = timl#hash#compute(a:key)
  let level = 1
  let node = a:node
  let idx = s:idx_for(hash, level)
  while has_key(node, idx)
    if type(node[idx]) == type([])
      for pair in node[idx]
        if timl#equality#test(a:key, pair[0])
          return pair
        endif
      endfor
      return g:timl#nil
    endif
    let level = level * 32
    let node = node[idx]
    let idx = s:idx_for(hash, level)
  endwhile
  return g:timl#nil
endfunction

function! timl#hash#items(node) abort
  let _ = {}
  let array = []
  for [k, _.v] in items(a:node)
    if type(_.v) == type([])
      call extend(array, _.v)
    else
      call extend(array, timl#hash#items(_.v))
    endif
  endfor
  return array
endfunction

function! timl#hash#assoc(node, key, val) abort
  let hash = timl#hash#compute(a:key)
  return s:assoc(a:node, hash, a:key, a:val, 1)
endfunction

function! s:assoc(node, hash, key, val, level) abort
  let idx = s:idx_for(a:hash, a:level)
  if !has_key(a:node, idx)
    return [extend({idx : [[a:key, a:val]]}, a:node), 1]
  elseif type(a:node[idx]) == type([])
    let hash2 = timl#hash#compute(a:node[idx][0][0])
    if hash2 == a:hash
      for i in range(len(a:node[idx]))
        if timl#equality#test(a:key, a:node[idx][i][0])
          if a:node[idx][i][1] is# a:val
            return [a:node, 0]
          endif
          let node = extend({idx : copy(a:node[idx])}, a:node, 'keep')
          let node[idx][i] = [a:key, a:val]
          return [node, 0]
        endif
      endfor
      let node = copy(a:node)
      let node[idx] += [[a:key, a:val]]
      return [node, 1]
    else
      let node = extend({idx : {}}, a:node, 'keep')
      for old in a:node[idx]
        let [node, _] = s:assoc(node, hash2, old[0], old[1], a:level)
      endfor
      return s:assoc(node, a:hash, a:key, a:val, a:level)
    endif
  else
    let [node, c] = s:assoc(a:node[idx], a:hash, a:key, a:val, a:level * 32)
    if a:node[idx] is# node
      return [a:node, c]
    else
      return [extend({idx : node}, a:node, 'keep'), c]
    endif
  endif
endfunction

function! timl#hash#dissoc(node, key) abort
  let hash = timl#hash#compute(a:key)
  return s:dissoc(a:node, hash, a:key, 1)
endfunction

function! s:dissoc(node, hash, key, level) abort
  let idx = s:idx_for(a:hash, a:level)
  if !has_key(a:node, idx)
    return [a:node, 0]
  elseif type(a:node[idx]) == type([])
    let hash2 = timl#hash#compute(a:node[idx][0][0])
    if hash2 == a:hash
      for i in range(len(a:node[idx]))
        if timl#equality#test(a:key, a:node[idx][i][0])
          let node = extend({idx : copy(a:node[idx])}, a:node, 'keep')
          call remove(node[idx], i)
          return [node, 1]
        endif
      endfor
    endif
    return [a:node, 0]
  else
    let [node, c] = s:dissoc(a:node[idx], a:hash, a:key, a:level * 32)
    if node is# a:node[idx]
      return [a:node, c]
    elseif empty(node)
      let node2 = copy(node)
      call remove(node2, idx)
      return [node2, c]
    else
      return [extend({idx : node}, a:node, 'keep'), c]
    endif
  endif
endfunction
