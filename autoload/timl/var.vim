" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_var')
  finish
endif
let g:autoloaded_timl_var = 1

function! timl#var#get(var)
  return g:{a:var.munged}
endfunction

function! timl#var#invoke(var, ...)
  return timl#call(g:{a:var.munged}, a:000)
endfunction
