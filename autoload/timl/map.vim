" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_map")
  finish
endif
let g:autoloaded_timl_map = 1

function! timl#map#test(coll) abort
  return timl#type#canp(a:coll, g:timl#core.dissoc)
endfunction

let s:type = timl#type#core_create('HashMap')
function! timl#map#create(_) abort
  let keyvals = len(a:_) == 1 ? a:_[0] : a:_
  let map = s:empty
  for i in range(0, len(keyvals)-1, 16)
    let map = call('timl#map#assoc', [map] + keyvals[i : i+15])
  endfor
  lockvar 1 map
  return map
endfunction

function! timl#map#zip(keys, vals) abort
  let _ = {}
  let args = []
  let [_.keys, _.vals] = [timl#coll#seq(a:keys), timl#coll#seq(a:vals)]
  while _.keys isnot# g:timl#nil && _.vals isnot# g:timl#nil
    call extend(args, [timl#coll#first(_.keys), timl#coll#first(_.vals)])
    let [_.keys, _.vals] = [timl#coll#next(_.keys), timl#coll#next(_.vals)]
  endwhile
  return timl#map#create(args)
endfunction

function! timl#map#soft_coerce(coll) abort
  if timl#coll#sequentialp(a:coll)
    return timl#map#create(timl#array#coerce(a:coll))
  else
    return a:coll
  endif
endfunction

function! timl#map#to_array(this) abort
  return map(filter(items(a:this), 'v:val[0][0:1] !=# "__"'), '[timl#keyword#intern(v:val[0]), v:val[1]]') + timl#hash#items(a:this.__root)
endfunction

function! timl#map#length(this) abort
  return a:this.__length
endfunction

function! timl#map#equal(this, that) abort
  if a:this is# a:that
    return g:timl#true
  elseif !timl#map#test(a:that)
    return g:timl#false
  endif
  if timl#coll#count(a:this) !=# timl#coll#count(a:that)
    return g:timl#false
  endif
  let _ = {'seq': timl#coll#seq(a:this)}
  while _.seq isnot# g:timl#nil
    let _.other = timl#coll#get(a:that, timl#coll#ffirst(_.seq), _)
    if _.other is# _ || !timl#equality#test(timl#coll#first(timl#coll#nfirst(_.seq)), _.other)
      return g:timl#false
    endif
    let _.seq = timl#coll#next(_.seq)
  endwhile
  return g:timl#true
endfunction

function! timl#map#seq(this) abort
  let items = timl#map#to_array(a:this)
  return empty(items) ? g:timl#nil : timl#array_seq#create(items)
endfunction

function! timl#map#lookup(this, key, ...) abort
  if timl#keyword#test(a:key) && a:key.str !~# '^__'
    return get(a:this, a:key.str, a:0 ? a:1 : g:timl#nil)
  else
    return get(timl#hash#find(a:this.__root, a:key), 1, a:0 ? a:1 : g:timl#nil)
  endif
endfunction

if !exists('s:empty')
  let s:empty = timl#type#bless(s:type, {'__root': {}, '__length': 0})
  lockvar s:empty
endif
function! timl#map#empty(this) abort
  return s:empty
endfunction

function! timl#map#conj(this, ...) abort
  let _ = {}
  let this = a:this
  for _.e in a:000
    let this = timl#map#assoc(this, timl#coll#first(_.e), timl#coll#fnext(_.e))
  endfor
  return this
endfunction

function! timl#map#assoc(this, ...) abort
  let this = copy(a:this)
  for i in range(0, len(a:000)-2, 2)
    if timl#keyword#test(a:000[i]) && a:000[i].str !~# '^__'
      if !has_key(this, a:000[i].str)
        let this.__length += 1
      endif
      let this[a:000[i].str] = a:000[i+1]
    else
      let [this.__root, c] = timl#hash#assoc(this.__root, a:000[i], a:000[i+1])
      let this.__length += c
    endif
  endfor
  lockvar 1 this
  return this
endfunction

function! timl#map#dissoc(this, ...) abort
  let _ = {}
  let this = copy(a:this)
  for _.x in a:000
    if timl#keyword#test(_.x) && _.x.str !~# '^__'
      if has_key(this, _.x.str)
        call remove(this, _.x.str)
        let this.__length -= 1
      endif
    else
      let [this.__root, c] = timl#hash#dissoc(this.__root, _.x)
      let this.__length -= c
    endif
  endfor
  lockvar 1 this
  return this
endfunction

function! timl#map#call(this, _) abort
  return call('timl#map#lookup', [a:this] + a:_)
endfunction
