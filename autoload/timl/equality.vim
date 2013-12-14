" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_equality')
  finish
endif
let g:autoloaded_timl_equality = 1

function! timl#equality#all(_) abort
  let _ = {}
  for _.y in a:_[1:-1]
    if !timl#equalp(a:_[0], _.y)
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
  if a:y is# g:timl#nil
    return g:timl#false
  elseif a:x is# a:y
    return g:timl#true
  endif
  let _ = {'x': timl#seq(a:x), 'y': timl#seq(a:y)}
  while _.x isnot# g:timl#nil && _.y isnot# g:timl#nil
    if !timl#equalp(timl#first(_.x), timl#first(_.y))
      return g:timl#false
    endif
    let _.x = timl#next(_.x)
    let _.y = timl#next(_.y)
  endwhile
  return _.x is# g:timl#nil && _.y is# g:timl#nil ? g:timl#true : g:timl#false
endfunction
