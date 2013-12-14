" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_map")
  finish
endif
let g:autoloaded_timl_map = 1

let s:type = timl#type#intern('timl.lang/HashMap')
function! timl#map#create(_) abort
  let keyvals = len(a:_) == 1 ? a:_[0] : a:_
  let map = timl#bless(s:type)
  for i in range(0, len(keyvals)-1, 2)
    let map[timl#key(keyvals[i])] = get(keyvals, i+1, g:timl#nil)
  endfor
  lockvar 1 map
  return map
endfunction

function! timl#map#seq(dict) abort
  let items = map(filter(items(a:dict), 'v:val[0][0] !=# "#"'), '[timl#dekey(v:val[0]), v:val[1]]')
  return empty(items) ? g:timl#nil : timl#array_seq#create(items)
endfunction

function! timl#map#lookup(this, key, ...) abort
  return get(a:this, timl#key(a:key), a:0 ? a:1 : g:timl#nil)
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
    let this[timl#key(timl#first(_.e))] = timl#fnext(_.e)
  endfor
  lockvar 1 this
  return this
endfunction

function! timl#map#conjb(this, ...) abort
  let _ = {}
  for _.e in a:000
    let a:this[timl#key(timl#first(_.e))] = timl#fnext(_.e)
  endfor
  return a:this
endfunction

function! timl#map#assoc(this, ...) abort
  let this = copy(a:this)
  for i in range(0, len(a:000)-2, 2)
    let this[timl#key(a:000[i])] = a:000[i+1]
  endfor
  lockvar 1 this
  return this
endfunction

function! timl#map#assocb(this, ...) abort
  for i in range(0, len(a:000)-2, 2)
    let a:this[timl#key(a:000[i])] = a:000[i+1]
  endfor
  return a:this
endfunction

function! timl#map#dissoc(this, ...) abort
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

function! timl#map#dissocb(this, ...) abort
  let _ = {}
  for _.x in a:000
    let key = timl#key(_.x)
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
