" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_set")
  finish
endif
let g:autoloaded_timl_set = 1

let s:type = timl#type#intern('timl.lang/HashSet')
function! timl#set#coerce(seq) abort
  let _ = {}
  let dict = timl#bless(s:type)
  if type(a:seq) == type([])
    for _.val in a:seq
      let dict[timl#key(_.val)] = _.val
    endfor
  elseif timl#setp(a:seq)
    return a:seq
  else
    let _.seq = timl#seq(a:seq)
    while _.seq isnot# g:timl#nil
      let dict[timl#key(timl#first(_.seq))] = timl#first(_.seq)
      let _.seq = timl#next(_.seq)
    endwhile
  endif
  lockvar 1 dict
  return dict
endfunction

function! timl#set#to_array(this) abort
  return map(filter(items(a:this), 'v:val[0][0] !=# "#"'), 'v:val[1]')
endfunction

function! timl#set#count(this) abort
  return len(timl#set#to_array(a:this))
endfunction

function! timl#set#seq(this) abort
  let items = timl#set#to_array(a:this)
  return empty(items) ? g:timl#nil : timl#array_seq#create(items)
endfunction

function! timl#set#equal(this, that)
  if a:this is# a:that
    return g:timl#true
  elseif !timl#setp(a:that)
    return g:timl#false
  endif
  if timl#count(a:this) !=# timl#count(a:that)
    return g:timl#false
  endif
  let _ = {'seq': timl#seq(a:this)}
  while _.seq isnot# g:timl#nil
    if timl#get(a:that, timl#first(_.seq), _) is _
      return g:timl#false
    endif
    let _.seq = timl#next(_.seq)
  endwhile
  return g:timl#true
endfunction

function! timl#set#lookup(this, key, ...) abort
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

if !exists('s:empty')
  let s:empty = timl#bless('timl.lang/HashSet')
  lockvar s:empty
endif
function! timl#set#empty(this) abort
  return s:empty
endfunction

function! timl#set#conj(this, ...) abort
  let this = copy(a:this)
  let _ = {}
  for _.e in a:000
    let this[timl#key(_.e)] = _.e
  endfor
  lockvar 1 this
  return this
endfunction

function! timl#set#conjb(this, ...) abort
  let _ = {}
  for _.e in a:000
    let a:this[timl#key(_.e)] = _.e
  endfor
  return a:this
endfunction

function! timl#set#disj(this, ...) abort
  let _ = {}
  let this = copy(a:this)
  for _.x in a:000
    let key = timl#key(_.x)
    if has_key(this, key)
      call remove(this, key)
    endif
  endfor
  lockvar 1 this
  return this
endfunction

function! timl#set#disjb(this, ...) abort
  let _ = {}
  for _.x in a:000
    let key = timl#key(_.x)
    if has_key(a:this, key)
      call remove(a:this, key)
    endif
  endfor
  return a:this
endfunction

function! timl#set#transient(this) abort
  let this = a:this
  return islocked('this') ? copy(this) : this
endfunction

function! timl#set#persistentb(this) abort
  lockvar 1 a:this
  return a:this
endfunction
