" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:timl_autoloaded_coll')
  finish
endif
let g:timl_autoloaded_coll = 1

function! timl#coll#test(coll) abort
  return timl#type#canp(a:coll, g:timl#core#conj)
endfunction

function! timl#coll#chunked_seqp(coll) abort
  return timl#type#canp(a:coll, g:timl#core#chunk_first)
endfunction

function! timl#coll#get(coll, key, ...) abort
  return timl#invoke(g:timl#core#lookup, a:coll, a:key, a:0 ? a:1 : g:timl#nil)
endfunction

function! timl#coll#containsp(coll, val) abort
  let sentinel = {}
  return timl#coll#get(a:coll, a:val, sentinel) isnot# sentinel
endfunction

function! timl#coll#count(counted) abort
  if timl#type#canp(a:counted, g:timl#core#length)
    return timl#invoke(g:timl#core#length, a:counted)
  endif
  let _ = {'seq': timl#seq(a:counted)}
  let c = 0
  while !timl#type#canp(_.seq, g:timl#core#length)
    let _.seq = timl#next(_.seq)
    let c += 1
  endwhile
  return c + timl#invoke(g:timl#core#length, _.seq)
endfunction

function! timl#coll#into(coll, seq) abort
  let t = timl#type#string(a:coll)
  if timl#type#canp(a:coll, g:timl#core#transient)
    let _ = {'coll': timl#invoke(g:timl#core#transient, a:coll), 'seq': timl#seq(a:seq)}
    while _.seq isnot# g:timl#nil
      let _.coll = timl#invoke(g:timl#core#conj_BANG_, _.coll, timl#first(_.seq))
      let _.seq = timl#next(_.seq)
    endwhile
    return timl#invoke(g:timl#core#persistent_BANG_, _.coll)
  else
    let _ = {'coll': a:coll, 'seq': timl#seq(a:seq)}
    while _.seq isnot# g:timl#nil
      let _.coll = timl#invoke(g:timl#core#conj, _.coll, timl#first(_.seq))
      let _.seq = timl#next(_.seq)
    endwhile
    return _.coll
  endif
endfunction

function! timl#coll#reduce(f, coll, ...) abort
  let _ = {}
  if a:0
    let _.val = a:coll
    let _.seq = timl#seq(a:1)
  else
    let _.seq = timl#seq(a:coll)
    if empty(_.seq)
      return g:timl#nil
    endif
    let _.val = timl#first(_.seq)
    let _.seq = timl#rest(_.seq)
  endif
  while _.seq isnot# g:timl#nil
    let _.val = timl#invoke(a:f, _.val, timl#first(_.seq))
    let _.seq = timl#next(_.seq)
  endwhile
  return _.val
endfunction

function! timl#coll#mutating_map(f, coll) abort
  return map(a:coll, 'timl#call(a:f, [v:val])')
endfunction

function! timl#coll#mutating_filter(pred, coll) abort
  return filter(a:coll, 'timl#truth(timl#call(a:pred, [v:val]))')
endfunction
