" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_cons")
  finish
endif
let g:autoloaded_timl_cons = 1

let s:type = timl#type#intern('timl.lang/Cons')

function! timl#cons#create(car, cdr)
  if timl#type#canp(a:cdr, g:timl#core#seq)
    let cons = timl#bless(s:type, {'car': a:car, 'cdr': a:cdr is# g:timl#nil ? g:timl#empty_list : a:cdr})
    lockvar 1 cons
    return cons
  endif
  throw 'timl: not seqable'
endfunction

function! timl#cons#conj(this, ...)
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

function! timl#cons#test(cons)
  return type(a:obj) == type({}) && get(a:obj, '#tag') is# s:type
endfunction
