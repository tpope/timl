if exists("g:autoloaded_timl_lang_hash_set")
  finish
endif
let g:autoloaded_timl_lang_hash_set = 1

function! timl#lang#hash_set#seq(hash)
  return timl#persistent(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), 'v:val[1]'))
endfunction
