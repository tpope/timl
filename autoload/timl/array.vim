" Maintainer: Tim Pope <http://tpo.pe/>

if !exists('g:autoloaded_timl_array')
  let g:autoloaded_timl_array = 1
endif

function! timl#array#lock(array) abort
  lockvar 1 a:array
  return a:array
  " let locked = map(copy(a:array), "islocked('v:val')")
  " lockvar 2 a:array
  " for i in range(len(a:array))
  "   if !locked[i] && type(a:array[i]) =~# '^[34]$'
  "     unlockvar 1 a:array[i]
  "   endif
  " endfor
  " return a:array
endfunction

let s:type = type([])
function! timl#array#coerce(seq) abort
  if type(a:seq) ==# s:type
    return a:seq is# g:timl#nil ? [] : a:seq
  endif
  let array = []
  let _ = {'seq': timl#seq(a:seq)}
  while _.seq isnot# g:timl#nil
    call add(array, timl#first(_.seq))
    let _.seq = timl#next(_.seq)
  endwhile
  return array
endfunction

function! timl#array#seq(this) abort
  return empty(a:this) ? g:timl#nil : timl#array_seq#create(a:this)
endfunction

function! timl#array#first(this) abort
  return get(a:this, 0, g:timl#nil)
endfunction

function! timl#array#rest(this) abort
  return len(a:this) <= 1 ? g:timl#empty_list : timl#array_seq#create(a:this, 1)
endfunction

function! timl#array#lookup(this, idx, ...) abort
  if type(a:idx) == type(0)
    return get(a:this, a:idx, a:0 ? a:1 g:timl#nil)
  endif
  return a:0 ? a:1 : g:timl#nil
endfunction

function! timl#array#nth(this, idx, ...) abort
  let idx = timl#int(a:idx)
  if a:0
    return get(a:this, idx, a:1)
  else
    return a:this[idx]
  endif
endfunction

function! timl#array#conj(this, ...) abort
  let this = a:this
  let that = a:this + a:000
  if islocked('this')
    lockvar 1 that
  endif
  return that
endfunction

function! timl#array#conjb(this, ...) abort
  return extend(a:this, a:000)
endfunction

function! timl#array#empty(this) abort
  let this = a:this
  let empty = []
  if islocked('this')
    lockvar 1 empty
  endif
  return this
endfunction

function! timl#array#transient(this) abort
  let this = a:this
  return islocked('this') ? copy(this) : this
endfunction

function! timl#array#persistentb(this) abort
  lockvar 1 a:this
  return a:this
endfunction
