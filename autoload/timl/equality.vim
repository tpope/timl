" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_equality')
  finish
endif
let g:autoloaded_timl_equality = 1

function! timl#equality#all(_) abort
  let _ = {}
  for _.y in a:_[1:-1]
    if !timl#truth(timl#type#dispatch(g:timl#core#equal_QMARK_, a:_[0], _.y))
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
      return s:false
    endif
  endfor
  return s:true
endfunction
