" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_funcref")
  finish
endif
let g:autoloaded_timl_funcref = 1

function! timl#funcref#call(this, _) abort
  return call(a:this, a:_)
endfunction
