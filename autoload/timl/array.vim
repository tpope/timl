" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_array')
  finish
endif
let g:autoloaded_timl_array = 1

function! timl#array#lock(array) abort
  lockvar 1 a:array
  return a:array
endfunction

let s:type = type([])
function! timl#array#coerce(seq) abort
  if type(a:seq) ==# s:type
    return a:seq is# g:timl#nil ? [] : a:seq
  elseif timl#type#string(a:seq) ==# 'timl.lang/Vector'
    return copy(a:seq.array)
  endif
  let array = []
  let _ = {'seq': timl#coll#seq(a:seq)}
  while _.seq isnot# g:timl#nil
    call add(array, timl#coll#first(_.seq))
    let _.seq = timl#coll#next(_.seq)
  endwhile
  return array
endfunction

function! timl#array#seq(this, ...) abort
  return len(a:this) <= (a:0 ? a:1 : 0) ? g:timl#nil : timl#array_seq#create(a:this, a:0 ? a:1 : 0)
endfunction

function! timl#array#car(this) abort
  return get(a:this, 0, g:timl#nil)
endfunction

function! timl#array#cdr(this) abort
  return len(a:this) <= 1 ? g:timl#empty_list : timl#array_seq#create(a:this, 1)
endfunction

function! timl#array#lookup(this, idx, ...) abort
  if type(a:idx) == type(0)
    return get(a:this, a:idx, a:0 ? a:1 g:timl#nil)
  endif
  return a:0 ? a:1 : g:timl#nil
endfunction

function! timl#array#nth(this, idx, ...) abort
  let idx = timl#number#int(a:idx)
  if a:0
    return get(a:this, idx, a:1)
  else
    return a:this[idx]
  endif
endfunction

function! timl#array#conj(this, ...) abort
  return a:this + a:000
endfunction

function! timl#array#conjb(this, ...) abort
  return extend(a:this, a:000)
endfunction

function! timl#array#assocb(this, ...) abort
  let this = a:this
  for i in range(0, len(a:000)-2, 2)
    if (timl#number#integerp(a:000[i]) && a:000[i] ==# len(a:this)) || islocked('this')
      call add(this, a:000[i+1])
    else
      let this[a:000[i]] = a:000[i+1]
    endif
  endfor
  return this
endfunction

function! timl#array#dissocb(this, ...) abort
  let _ = {}
  for _.key in a:000
    if timl#number#integerp(_.key) && _.key < len(a:this) && (-_.key-1) < len(a:this)
      call remove(a:this, _.key)
    endif
  endfor
  return a:this
endfunction

function! timl#array#empty(this) abort
  return []
endfunction

function! timl#array#persistentb(this) abort
  return timl#vector#claim(a:this)
endfunction
