" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_number")
  finish
endif
let g:autoloaded_timl_number = 1

let s:int = type(0)
let s:float = 5

function! timl#number#coerce(obj) abort
  if type(a:obj) == s:int || type(a:obj) == s:float
    return a:obj
  endif
  throw "timl: not a number"
endfunction

function! timl#number#int(obj) abort
  if type(a:obj) == s:int
    return a:obj
  elseif type(a:obj) == s:float
    return float2nr(a:obj)
  endif
  throw "timl: not a number"
endfunction

function! timl#number#float(obj) abort
  if type(a:obj) == s:tfloat
    return a:obj
  elseif type(a:obj) == s:tint
    return 0.0 + a:obj
  endif
  throw "timl: not a float"
endfunction

function! timl#number#test(obj) abort
  return type(a:obj) == s:int || type(a:obj) == s:float
endfunction

function! timl#number#integerp(obj) abort
  return type(a:obj) == s:int
endfunction

function! timl#number#floatp(obj) abort
  return type(a:obj) == s:float
endfunction

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
    let acc = timl#number#coerce(a:_[0])
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
    let acc = timl#number#coerce(a:_[0])
    for elem in a:_[1:-1]
      let acc = acc / elem
    endfor
    return acc
  endif
  throw 'timl: arity error'
endfunction

function! timl#number#gt(_) abort
  if empty(a:_)
    throw 'timl: arity error'
  endif
  let x = timl#number#coerce(a:_[0])
  for y in map(a:_[1:-1], 'timl#number#coerce(v:val)')
    if !(x > y)
      return g:timl#false
    endif
    let x = y
  endfor
  return g:timl#true
endfunction

function! timl#number#lt(_) abort
  if empty(a:_)
    throw 'timl: arity error'
  endif
  let x = timl#number#coerce(a:_[0])
  for y in map(a:_[1:-1], 'timl#number#coerce(v:val)')
    if !(x < y)
      return g:timl#false
    endif
    let x = y
  endfor
  return g:timl#true
endfunction

function! timl#number#gteq(_) abort
  if empty(a:_)
    throw 'timl: arity error'
  endif
  let x = timl#number#coerce(a:_[0])
  for y in map(a:_[1:-1], 'timl#number#coerce(v:val)')
    if !(x >= y)
      return g:timl#false
    endif
    let x = y
  endfor
  return g:timl#true
endfunction

function! timl#number#lteq(_) abort
  if empty(a:_)
    throw 'timl: arity error'
  endif
  let x = timl#number#coerce(a:_[0])
  for y in map(a:_[1:-1], 'timl#number#coerce(v:val)')
    if !(x <= y)
      return g:timl#false
    endif
    let x = y
  endfor
  return g:timl#true
endfunction

function! timl#number#equiv(_) abort
  if empty(a:_)
    throw 'timl: arity error'
  endif
  let x = timl#number#coerce(a:_[0])
  for y in map(a:_[1:-1], 'timl#number#coerce(v:val)')
    if x != y
      return g:timl#false
    endif
  endfor
  return g:timl#true
endfunction

function! timl#number#inc(x) abort
  return timl#number#coerce(a:x) + 1
endfunction

function! timl#number#dec(x) abort
  return timl#number#coerce(a:x) - 1
endfunction

function! timl#number#rem(x, y) abort
  return timl#number#coerce(a:x) % a:y
endfunction

function! timl#number#quot(x, y) abort
  return type(a:x) == 5 || type(a:y) == 5 ? trunc(a:x/a:y) : timl#number#coerce(a:x)/a:y
endfunction

function! timl#number#mod(x, y) abort
  if (timl#number#coerce(a:x) < 0 && timl#number#coerce(a:y) > 0 || timl#number#coerce(a:x) > 0 && timl#number#coerce(a:y) < 0) && a:x % a:y != 0
    return (a:x % a:y) + a:y
  else
    return a:x % a:y
  endif
endfunction

function! timl#number#bit_not(x) abort
  return invert(a:x)
endfunction

function! timl#number#bit_or(_) abort
  let acc = 0
  for i in map(copy(a:_), 'timl#number#int(v:val)')
    let acc = or(acc, i)
  endfor
  return acc
endfunction

function! timl#number#bit_xor(_) abort
  let acc = 0
  for i in map(copy(a:_), 'timl#number#int(v:val)')
    let acc = xor(acc, i)
  endfor
  return acc
endfunction

function! timl#number#bit_and(_) abort
  let acc = -1
  for i in map(copy(a:_), 'timl#number#int(v:val)')
    let acc = and(acc, i)
  endfor
  return acc
endfunction

function! timl#number#bit_and_not(_) abort
  let acc = timl#number#int(a:_[0])
  for i in map(a:_[1:-1], 'timl#number#int(v:val)')
    let acc = and(acc, invert(i))
  endfor
  return acc
endfunction

function! timl#number#bit_shift_left(x, n) abort
  let x = timl#number#int(a:x)
  for i in range(timl#number#int(a:n))
    let x = x * 2
  endfor
  return x
endfunction

function! timl#number#bit_shift_right(x, n) abort
  let x = timl#number#int(a:x)
  for i in range(timl#number#int(a:n))
    let x = x / 2
  endfor
  return x
endfunction

function! timl#number#bit_flip(x, n) abort
  return xor(a:x, g:timl#core.bit_shift_left.call(1, a:n))
endfunction

function! timl#number#bit_set(x, n) abort
  return or(a:x, g:timl#core.bit_shift_left.call(1, a:n))
endfunction

function! timl#number#bit_clear(x, n) abort
  return and(a:x, invert(g:timl#core.bit_shift_left.call(1, a:n)))
endfunction

function! timl#number#bit_test(x, n) abort
  return and(a:x, g:timl#core.bit_shift_left.call(1, a:n))
endfunction

function! timl#number#not_negative(x) abort
  return timl#number#coerce(a:x) < 0 ? g:timl#nil : a:x
endfunction

function! timl#number#zerop(x) abort
  return timl#number#coerce(a:x) == 0
endfunction

function! timl#number#nonzerop(x) abort
  return timl#number#coerce(a:x) != 0
endfunction

function! timl#number#posp(x) abort
  return timl#number#coerce(a:x) > 0
endfunction

function! timl#number#negp(x) abort
  return timl#number#coerce(a:x) < 0
endfunction

function! timl#number#oddp(x) abort
  return timl#number#coerce(a:x) % 2
endfunction

function! timl#number#evenp(x) abort
  return timl#number#coerce(a:x) % 2 == 0
endfunction
