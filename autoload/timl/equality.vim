" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_equality')
  finish
endif
let g:autoloaded_timl_equality = 1

function! timl#equality#test(x, y) abort
  if timl#type#canp(a:x, g:timl#core.equiv)
    return timl#truth(timl#invoke(g:timl#core.equiv, a:x, a:y))
  else
    return type(a:x) ==# type(a:y) && a:x ==# a:y
  endif
endfunction

function! timl#equality#all(_) abort
  let _ = {}
  for _.y in a:_[1:-1]
    if !timl#equality#test(a:_[0], _.y)
      return g:timl#false
    endif
  endfor
  return g:timl#true
endfunction

function! timl#equality#not(_) abort
  return timl#equality#all(a:_) ==# g:timl#false ? g:timl#true : g:timl#false
endfunction

function! timl#equality#identical(_) abort
  let _ = {}
  for _.y in a:_[1:-1]
    if a:_[0] isnot# _.y
      return g:timl#false
    endif
  endfor
  return g:timl#true
endfunction

function! timl#equality#seq(x, y) abort
  if a:x is# a:y
    return g:timl#true
  elseif !timl#coll#sequentialp(a:y)
    return g:timl#false
  endif
  let _ = {'x': timl#coll#seq(a:x), 'y': timl#coll#seq(a:y)}
  while _.x isnot# g:timl#nil && _.y isnot# g:timl#nil
    if !timl#equality#test(timl#coll#first(_.x), timl#coll#first(_.y))
      return g:timl#false
    endif
    let _.x = timl#coll#next(_.x)
    let _.y = timl#coll#next(_.y)
  endwhile
  return _.x is# g:timl#nil && _.y is# g:timl#nil ? g:timl#true : g:timl#false
endfunction
