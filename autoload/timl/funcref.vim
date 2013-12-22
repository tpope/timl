" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_funcref")
  finish
endif
let g:autoloaded_timl_funcref = 1

function! timl#funcref#call(this, _) abort
  return call(a:this, a:_)
endfunction

let s:type = type(function('tr'))
function! timl#funcref#test(this) abort
  return type(a:this) == s:type
endfunction
