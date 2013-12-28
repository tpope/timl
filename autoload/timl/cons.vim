" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_cons")
  finish
endif
let g:autoloaded_timl_cons = 1

let s:type = timl#type#intern('timl.lang/Cons')

function! timl#cons#test(obj) abort
  return type(a:obj) == type({}) && get(a:obj, '__tag__') is# s:type
endfunction

function! timl#cons#create(car, cdr, ...) abort
  if timl#type#canp(a:cdr, g:timl#core#seq)
    let cons = timl#type#bless(s:type, {'car': a:car, 'cdr': a:cdr is# g:timl#nil ? g:timl#empty_list : a:cdr, 'meta': a:0 ? a:1 : g:timl#nil})
    lockvar 1 cons
    return cons
  endif
  throw 'timl: not seqable'
endfunction

function! timl#cons#spread(array) abort
  if empty(a:array)
    throw 'timl: arity error'
  elseif !timl#seqp(a:array[-1])
    throw 'timl: seq required'
  endif
  let _ = {'cdr': a:array[-1]}
  for i in range(len(a:array)-2, 0, -1)
    let _.cdr = timl#cons#create(a:array[i], _.cdr)
  endfor
  return _.cdr
endfunction

function! timl#cons#conj(this, ...) abort
  let head = a:this
  let _ = {}
  for _.e in a:000
    let head = timl#cons#create(_.e, head)
  endfor
  return head
endfunction

function! timl#cons#first(this)
  return a:this.car
endfunction

function! timl#cons#more(this)
  return a:this.cdr
endfunction
