" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_number")
  finish
endif
let g:autoloaded_timl_number = 1

function! timl#number#sum(_) abort
  let acc = 0
  for elem in a:_
    let acc += elem
  endfor
  return acc
endfunction

function! timl#number#product(_) abort
  let acc = 1
  for elem in a:_
    let acc = acc * elem
  endfor
  return acc
endfunction

function! timl#number#minus(_) abort
  if len(a:_) ==# 1
    return 0 - a:_[0]
  elseif len(a:_)
    let acc = timl#num(a:_[0])
    for elem in a:_[1:-1]
      let acc -= elem
    endfor
    return acc
  endif
  throw 'timl: arity error'
endfunction

function! timl#number#solidus(_) abort
  if len(a:_) ==# 1
    return 1 / a:_[0]
  elseif len(a:_)
    let acc = timl#num(a:_[0])
    for elem in a:_[1:-1]
      let acc = acc / elem
    endfor
    return acc
  endif
  throw 'timl: arity error'
endfunction

function! timl#number#gt(_)
  if empty(a:_)
    throw 'timl: arity error'
  endif
  let x = timl#num(a:_[0])
  for y in map(a:_[1:-1], 'timl#num(v:val)')
    if !(x > y)
      return g:timl#false
    endif
    let x = y
  endfor
  return g:timl#true
endfunction

function! timl#number#lt(_)
  if empty(a:_)
    throw 'timl: arity error'
  endif
  let x = timl#num(a:_[0])
  for y in map(a:_[1:-1], 'timl#num(v:val)')
    if !(x < y)
      return g:timl#false
    endif
    let x = y
  endfor
  return g:timl#true
endfunction

function! timl#number#gteq(_)
  if empty(a:_)
    throw 'timl: arity error'
  endif
  let x = timl#num(a:_[0])
  for y in map(a:_[1:-1], 'timl#num(v:val)')
    if !(x >= y)
      return g:timl#false
    endif
    let x = y
  endfor
  return g:timl#true
endfunction

function! timl#number#lteq(_)
  if empty(a:_)
    throw 'timl: arity error'
  endif
  let x = timl#num(a:_[0])
  for y in map(a:_[1:-1], 'timl#num(v:val)')
    if !(x <= y)
      return g:timl#false
    endif
    let x = y
  endfor
  return g:timl#true
endfunction

function! timl#number#equiv(_)
  if empty(a:_)
    throw 'timl: arity error'
  endif
  let x = timl#num(a:_[0])
  for y in map(a:_[1:-1], 'timl#num(v:val)')
    if x != y
      return g:timl#false
    endif
  endfor
  return g:timl#true
endfunction
