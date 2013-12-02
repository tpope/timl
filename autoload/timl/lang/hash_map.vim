if exists("g:autoloaded_timl_lang_hash_map")
  finish
endif
let g:autoloaded_timl_lang_hash_map = 1

function! timl#lang#hash_map#seq(hash)
  return timl#persistent(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), '[timl#dekey(v:val[0]), v:val[1]]'))
endfunction
