" Maintainer: Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_false")
  finish
endif
let g:autoloaded_timl_false = 1

if !exists('g:timl#false')
  let g:timl#false = timl#type#bless(timl#type#core_create('Boolean'), {'val': 0})
  lockvar 1 g:timl#false
endif

function! timl#false#identity() abort
  return g:timl#false
endfunction

function! timl#false#test(val) abort
  return a:val is# g:timl#false
endfunction
