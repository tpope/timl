let g:timl#cons#token = timl#symbol('#cons')

function! timl#cons#p(obj)
  if type(a:obj) == type([]) && get(a:obj,0) is g:timl#cons#token
endfunction

function! timl#cons#from_array(array)
  let cdr = g:timl#nil
  for i in range(len(a:array)-1, 0, -1)
    let cdr = timl#persist(g:timl#cons#token, a:array[i], cdr)
  endfor
  return cdr
endfunction

function! timl#cons#to_array(cons)
  if !timl#cons#p(a:cons)
    return a:cons
  endif
  let array = []
  let cons = a:cons
  while timl#cons#p(cons)
    call add(array, cons[1])
    let cons = cons[2]
  endwhile
  return array
endfunction
