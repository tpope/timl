if exists("g:autoloaded_timl_lang_hash_map")
  finish
endif
let g:autoloaded_timl_lang_hash_map = 1

function! timl#lang#hash_map#seq(hash)
  return timl#persistent(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), '[timl#dekey(v:val[0]), v:val[1]]'))
endfunction

function! timl#lang#hash_map#eval(hash, env)
  let _ = {}
  let dict = {'#tag': timl#symbol('#timl#lang#hash-map')}
  for [_.k, _.v] in timl#lang#hash_map#seq(a:hash)
    let dict[timl#key(timl#eval(_.k, a:env))] = timl#eval(_.v, a:env)
  endfor
  return timl#lock(dict)
endfunction
