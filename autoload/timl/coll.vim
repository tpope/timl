" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:timl_autoloaded_coll')
  finish
endif
let g:timl_autoloaded_coll = 1

function! timl#coll#test(coll) abort
  return timl#type#canp(a:coll, g:timl#core.conj)
endfunction

function! timl#coll#seq(coll) abort
  return timl#invoke(g:timl#core.seq, a:coll)
endfunction

function! timl#coll#emptyp(seq) abort
  return timl#coll#seq(a:seq) is# g:timl#nil
endfunction

function! timl#coll#sequentialp(coll) abort
  return a:coll isnot# g:timl#nil && timl#type#canp(a:coll, g:timl#core.car)
endfunction

function! timl#coll#seqp(obj) abort
  return timl#type#string(a:obj) =~# '^timl\.lang/\%(Cons\|EmptyList\)$' ||
        \ (timl#type#canp(a:obj, g:timl#core.car) && !timl#vector#test(a:obj))
endfunction

function! timl#coll#first(coll) abort
  if timl#cons#test(a:coll)
    return a:coll.car
  elseif type(a:coll) == type([])
    return get(a:coll, 0, g:timl#nil)
  elseif timl#type#canp(a:coll, g:timl#core.car)
    return timl#invoke(g:timl#core.car, a:coll)
  else
    return timl#invoke(g:timl#core.car, timl#coll#seq(a:coll))
  endif
endfunction

function! timl#coll#rest(coll) abort
  if timl#cons#test(a:coll)
    return a:coll.cdr
  elseif timl#type#canp(a:coll, g:timl#core.cdr)
    return timl#invoke(g:timl#core.cdr, a:coll)
  else
    return timl#invoke(g:timl#core.cdr, timl#coll#seq(a:coll))
  endif
endfunction

function! timl#coll#next(coll) abort
  let rest = timl#coll#rest(a:coll)
  return timl#coll#seq(rest)
endfunction

function! timl#coll#ffirst(seq) abort
  return timl#coll#first(timl#coll#first(a:seq))
endfunction

function! timl#coll#fnext(seq) abort
  return timl#coll#first(timl#coll#next(a:seq))
endfunction

function! timl#coll#nfirst(seq) abort
  return timl#coll#next(timl#coll#first(a:seq))
endfunction

function! timl#coll#nnext(seq) abort
  return timl#coll#next(timl#coll#next(a:seq))
endfunction

function! timl#coll#chunked_seqp(coll) abort
  return timl#type#canp(a:coll, g:timl#core.chunk_first)
endfunction

function! timl#coll#get(coll, key, ...) abort
  if timl#type#canp(a:coll, g:timl#core.lookup)
    return timl#invoke(g:timl#core.lookup, a:coll, a:key, a:0 ? a:1 : g:timl#nil)
  else
    return a:0 ? a:1 : g:timl#nil
  endif
endfunction

function! timl#coll#containsp(coll, val) abort
  let sentinel = {}
  return timl#coll#get(a:coll, a:val, sentinel) isnot# sentinel
endfunction

function! timl#coll#count(counted) abort
  if timl#type#canp(a:counted, g:timl#core.length)
    return timl#invoke(g:timl#core.length, a:counted)
  endif
  let _ = {'seq': timl#coll#seq(a:counted)}
  let c = 0
  while !timl#type#canp(_.seq, g:timl#core.length)
    let _.seq = timl#coll#next(_.seq)
    let c += 1
  endwhile
  return c + timl#invoke(g:timl#core.length, _.seq)
endfunction

function! timl#coll#into(coll, seq) abort
  let t = timl#type#string(a:coll)
  if timl#type#canp(a:coll, g:timl#core.transient)
    let _ = {'coll': timl#invoke(g:timl#core.transient, a:coll), 'seq': timl#coll#seq(a:seq)}
    while _.seq isnot# g:timl#nil
      let _.coll = timl#invoke(g:timl#core.conj_BANG_, _.coll, timl#coll#first(_.seq))
      let _.seq = timl#coll#next(_.seq)
    endwhile
    return timl#invoke(g:timl#core.persistent_BANG_, _.coll)
  else
    let _ = {'coll': a:coll, 'seq': timl#coll#seq(a:seq)}
    while _.seq isnot# g:timl#nil
      let _.coll = timl#invoke(g:timl#core.conj, _.coll, timl#coll#first(_.seq))
      let _.seq = timl#coll#next(_.seq)
    endwhile
    return _.coll
  endif
endfunction

function! timl#coll#reduce(f, coll, ...) abort
  let _ = {}
  if a:0
    let _.val = a:coll
    let _.seq = timl#coll#seq(a:1)
  else
    let _.seq = timl#coll#seq(a:coll)
    if empty(_.seq)
      return g:timl#nil
    endif
    let _.val = timl#coll#first(_.seq)
    let _.seq = timl#coll#rest(_.seq)
  endif
  while _.seq isnot# g:timl#nil
    let _.val = timl#invoke(a:f, _.val, timl#coll#first(_.seq))
    let _.seq = timl#coll#next(_.seq)
  endwhile
  return _.val
endfunction

function! timl#coll#mutating_map(f, coll) abort
  return map(a:coll, 'timl#call(a:f, [v:val])')
endfunction

function! timl#coll#mutating_filter(pred, coll) abort
  return filter(a:coll, 'timl#truth(timl#call(a:pred, [v:val]))')
endfunction
