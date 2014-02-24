" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_vector')
  finish
endif
let g:autoloaded_timl_vector = 1

function! timl#vector#test(obj) abort
  return timl#type#canp(a:obj, g:timl#core.nth)
endfunction

let s:type = timl#type#core_create('Vector')
function! timl#vector#claim(array) abort
  lockvar 1 a:array
  let vector = timl#type#bless(s:type, {'array': a:array})
  lockvar 1 vector
  return vector
endfunction

function! timl#vector#coerce(seq) abort
  if a:seq is# g:timl#nil
    return s:empty
  elseif type(a:seq) ==# type([])
    return timl#vector#claim(copy(a:seq))
  elseif timl#type#string(a:seq) ==# s:type.str
    return a:seq
  endif
  let array = []
  let _ = {'seq': timl#coll#seq(a:seq)}
  while _.seq isnot# g:timl#nil
    call add(array, timl#coll#first(_.seq))
    let _.seq = timl#coll#next(_.seq)
  endwhile
  return timl#vector#claim(array)
endfunction

function! timl#vector#seq(this) abort
  return timl#array#seq(a:this.array)
endfunction

function! timl#vector#length(this) abort
  return len(a:this.array)
endfunction

function! timl#vector#car(this) abort
  return get(a:this.array, 0, g:timl#nil)
endfunction

function! timl#vector#cdr(this) abort
  return len(a:this.array) <= 1 ? g:timl#empty_list : timl#array_seq#create(a:this.array, 1)
endfunction

function! timl#vector#lookup(this, idx, ...) abort
  if type(a:idx) == type(0) && a:idx >= 0
    return get(a:this.array, a:idx, a:0 ? a:1 : g:timl#nil)
  endif
  return a:0 ? a:1 : g:timl#nil
endfunction

function! timl#vector#nth(this, idx, ...) abort
  let idx = timl#number#int(a:idx)
  if a:0
    return get(a:this.array, idx, a:1)
  else
    return a:this.array[idx]
  endif
endfunction

function! timl#vector#conj(this, ...) abort
  return timl#vector#claim(a:this.array + a:000)
endfunction

let s:empty = timl#vector#claim([])
function! timl#vector#empty(this) abort
  return s:empty
endfunction

function! timl#vector#transient(this) abort
  return copy(a:this.array)
endfunction

function! timl#vector#sub(this, start, ...) abort
  let array = timl#vector#coerce(a:this).array
  if a:0 && a:1 == 0
    return s:empty
  elseif a:0
    return timl#vector#claim(array[a:start : (a:1 < 0 ? a:1 : a:1-1)])
  else
    return timl#vector#claim(array[a:start :])
  endif
endfunction

function! timl#vector#call(this, _) abort
  return call('timl#vector#lookup', [a:this] + a:_)
endfunction
