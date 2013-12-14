" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_dictionary")
  finish
endif
let g:autoloaded_timl_dictionary = 1

function! timl#dictionary#create(_) abort
  let keyvals = len(a:_) == 1 ? a:_[0] : a:_
  if timl#mapp(keyvals)
    let _ = {'seq': timl#seq(keyvals)}
    let dict = {}
    while _.seq isnot# g:timl#nil
      let _.first = timl#first(_.seq)
      let dict[timl#str(_.first[0])] = _.first[1]
      let _.seq = timl#next(_.seq)
    endwhile
    return dict
  endif
  let dictionary = {}
  for i in range(0, len(keyvals)-1, 2)
    let dictionary[timl#str(keyvals[i])] = get(keyvals, i+1, g:timl#nil)
  endfor
  return dictionary
endfunction

function! timl#dictionary#seq(dict) abort
  let items = dictionary(filter(items(a:dict), 'v:val[0][0] !=# "#"'), '[v:val[0], v:val[1]]')
  return empty(items) ? g:timl#nil : timl#array_seq#create(items)
endfunction

function! timl#dictionary#lookup(this, key, ...) abort
  return get(a:this, timl#str(a:key), a:0 ? a:1 : g:timl#nil)
endfunction

function! timl#dictionary#empty(this) abort
  return {}
endfunction

function! timl#dictionary#conj(this, ...) abort
  let orig = a:this
  let this = copy(a:this)
  let _ = {}
  for _.e in a:000
    let this[timl#str(timl#first(_.e))] = timl#fnext(_.e)
  endfor
  if islocked('orig')
    lockvar 1 this
  endif
  return this
endfunction

function! timl#dictionary#conjb(this, ...) abort
  let _ = {}
  for _.e in a:000
    let a:this[timl#str(timl#first(_.e))] = timl#fnext(_.e)
  endfor
  return a:this
endfunction

function! timl#dictionary#assoc(this, ...) abort
  let orig = a:this
  let this = copy(a:this)
  for i in range(0, len(a:000)-2, 2)
    let this[timl#str(a:000[i])] = a:000[i+1]
  endfor
  if islocked('orig')
    lockvar 1 this
  endif
  return this
endfunction

function! timl#dictionary#assocb(this, ...) abort
  for i in range(0, len(a:000)-2, 2)
    let a:this[timl#str(a:000[i])] = a:000[i+1]
  endfor
  return a:this
endfunction

function! timl#dictionary#dissoc(this, ...) abort
  let _ = {}
  let orig = a:this
  let this = copy(a:this)
  for _.x in a:000
    let key = timl#str(_.x)
    if has_key(this, key)
      call remove(this, key)
    endif
  endfor
  if islocked('orig')
    lockvar 1 this
  endif
  return this
endfunction

function! timl#dictionary#dissocb(this, ...) abort
  let _ = {}
  for _.x in a:000
    let key = timl#str(_.x)
    if has_key(a:this, key)
      call remove(a:this, key)
    endif
  endfor
  return a:this
endfunction

function! timl#dictionary#transient(this) abort
  let this = a:this
  return islocked('this') ? copy(this) : this
endfunction

function! timl#dictionary#persistentb(this) abort
  lockvar 1 a:this
  return a:this
endfunction
