" Maintainer: Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_true")
  finish
endif
let g:autoloaded_timl_true = 1

if !exists('g:timl#true')
  let g:timl#true = timl#type#bless(timl#type#core_create('Boolean'), {'val': 1})
  lockvar 1 g:timl#true
endif

function! timl#true#identity() abort
  return g:timl#true
endfunction

function! timl#true#test(val) abort
  return a:val is# g:timl#true
endfunction
