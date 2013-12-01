if exists("g:autoloaded_timl_lang_hash_set")
  finish
endif
let g:autoloaded_timl_lang_hash_set = 1

function! timl#lang#hash_set#seq(hash)
  return timl#persistent(map(filter(items(a:hash), 'v:val[0][0] !=# "#"'), 'v:val[1]'))
endfunction

function! timl#lang#hash_set#eval(hash, env)
  let _ = {}
  let dict = {'#tag': timl#symbol('#timl#lang#hash-set')}
  for _.v in timl#lang#hash_set#seq(a:hash)
    let _.e = timl#eval(_.v, a:env)
    let dict[timl#key(_.e)] = timl#eval(_.e)
  endfor
  return timl#lock(dict)
endfunction
