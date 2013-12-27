" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_map")
  finish
endif
let g:autoloaded_timl_map = 1

function! timl#map#key(key) abort
  if type(a:key) == type(0)
    return string(a:key)
  elseif timl#keyword#test(a:key) && a:key[0][0:1] !=# '__'
    return a:key[0]
  elseif a:key is# g:timl#nil
    return ' '
  else
    return ' '.timl#printer#string(a:key)
  endif
endfunction

function! timl#map#dekey(key)
  if a:key ==# ' '
    return g:timl#nil
  elseif a:key =~# '^ '
    return timl#reader#read_string(a:key[1:-1])
  elseif a:key =~# '^[-+]\=\d'
    return timl#reader#read_string(a:key)
  else
    return timl#keyword(a:key)
  endif
endfunction

let s:type = timl#type#intern('timl.lang/HashMap')
function! timl#map#create(_) abort
  let keyvals = len(a:_) == 1 ? a:_[0] : a:_
  let map = timl#bless(s:type)
  for i in range(0, len(keyvals)-1, 2)
    let map[timl#map#key(keyvals[i])] = get(keyvals, i+1, g:timl#nil)
  endfor
  lockvar 1 map
  return map
endfunction

function! timl#map#soft_coerce(coll) abort
  if timl#type#canp(a:coll, g:timl#core#more)
    return timl#map#create(timl#ary(a:coll))
  else
    return a:coll
  endif
endfunction

function! timl#map#to_array(this) abort
  return map(filter(items(a:this), 'v:val[0][0:1] !=# "__"'), '[timl#map#dekey(v:val[0]), v:val[1]]')
endfunction

function! timl#map#length(this) abort
  return len(timl#map#to_array(a:this))
endfunction

function! timl#map#equal(this, that)
  if a:this is# a:that
    return g:timl#true
  elseif !timl#mapp(a:that)
    return g:timl#false
  endif
  if timl#coll#count(a:this) !=# timl#coll#count(a:that)
    return g:timl#false
  endif
  let _ = {'seq': timl#seq(a:this)}
  while _.seq isnot# g:timl#nil
    let _.other = timl#coll#get(a:that, timl#ffirst(_.seq), _)
    if _.other is# _ || !timl#equalp(timl#first(timl#nfirst(_.seq)), _.other)
      return g:timl#false
    endif
    let _.seq = timl#next(_.seq)
  endwhile
  return g:timl#true
endfunction

function! timl#map#seq(this) abort
  let items = timl#map#to_array(a:this)
  return empty(items) ? g:timl#nil : timl#array_seq#create(items)
endfunction

function! timl#map#lookup(this, key, ...) abort
  return get(a:this, timl#map#key(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

if !exists('s:empty')
  let s:empty = timl#bless('timl.lang/HashMap')
  lockvar s:empty
endif
function! timl#map#empty(this) abort
  return s:empty
endfunction

function! timl#map#conj(this, ...) abort
  let this = copy(a:this)
  let _ = {}
  for _.e in a:000
    let this[timl#map#key(timl#first(_.e))] = timl#fnext(_.e)
  endfor
  lockvar 1 this
  return this
endfunction

function! timl#map#conjb(this, ...) abort
  let _ = {}
  for _.e in a:000
    let a:this[timl#map#key(timl#first(_.e))] = timl#fnext(_.e)
  endfor
  return a:this
endfunction

function! timl#map#assoc(this, ...) abort
  let this = copy(a:this)
  for i in range(0, len(a:000)-2, 2)
    let this[timl#map#key(a:000[i])] = a:000[i+1]
  endfor
  lockvar 1 this
  return this
endfunction

function! timl#map#assocb(this, ...) abort
  for i in range(0, len(a:000)-2, 2)
    let a:this[timl#map#key(a:000[i])] = a:000[i+1]
  endfor
  return a:this
endfunction

function! timl#map#dissoc(this, ...) abort
  let _ = {}
  let this = copy(a:this)
  for _.x in a:000
    let key = timl#map#key(_.x)
    if has_key(this, key)
      call remove(this, key)
    endif
  endfor
  lockvar 1 this
  return this
endfunction

function! timl#map#dissocb(this, ...) abort
  let _ = {}
  for _.x in a:000
    let key = timl#map#key(_.x)
    if has_key(a:this, key)
      call remove(a:this, key)
    endif
  endfor
  return a:this
endfunction

function! timl#map#transient(this) abort
  let this = a:this
  return islocked('this') ? copy(this) : this
endfunction

function! timl#map#persistentb(this) abort
  lockvar 1 a:this
  return a:this
endfunction

function! timl#map#call(this, _) abort
  return call('timl#map#lookup', [a:this] + a:_)
endfunction
