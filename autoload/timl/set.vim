" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_set")
  finish
endif
let g:autoloaded_timl_set = 1

function! timl#set#key(key)
  if type(a:key) == type(0)
    return string(a:key)
  elseif timl#keyword#test(a:key) && a:key[0][0:1] !=# '__'
    return a:key[0]
  elseif timl#symbol#test(a:key)
    return "'".a:key[0]
  elseif type(a:key) == type('')
    return '"'.a:key[0]
  elseif a:key is# g:timl#nil
    return ' '
  else
    return ''
  endif
endfunction

let s:type = timl#type#intern('timl.lang/HashSet')
let s:transient_type = timl#type#intern('timl.lang/TransientHashSet')
function! timl#set#coerce(seq) abort
  if timl#setp(a:seq)
    return a:seq
  endif
  let _ = {}
  let dict = timl#bless(s:transient_type, {'#extra': []})
  if type(a:seq) == type([])
    for _.val in a:seq
      call timl#set#conjb(dict, _.val)
    endfor
  else
    let _.seq = timl#seq(a:seq)
    while _.seq isnot# g:timl#nil
      call timl#set#conjb(dict, timl#first(_.seq))
      let _.seq = timl#next(_.seq)
    endwhile
  endif
  return timl#set#persistentb(dict)
endfunction

function! timl#set#to_array(this) abort
  return extend(map(filter(items(a:this), 'v:val[0][0] !=# "#" && v:val[0][0:1] !=# "__"'), 'v:val[1]'), a:this['#extra'])
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
  if timl#coll#count(a:this) !=# timl#coll#count(a:that)
    return g:timl#false
  endif
  let _ = {'seq': timl#seq(a:this)}
  while _.seq isnot# g:timl#nil
    if timl#coll#get(a:that, timl#first(_.seq), _) is# _
      return g:timl#false
    endif
    let _.seq = timl#next(_.seq)
  endwhile
  return g:timl#true
endfunction

function! timl#set#lookup(this, key, ...) abort
  let _ = {}
  let key = timl#set#key(a:key)
  if empty(key)
    for _.v in a:this['#extra']
      if timl#equalp(_.v, a:key)
        return _.v
      endif
    endfor
    return a:0 ? a:1 g:timl#nil
  else
    return get(a:this, key, a:0 ? a:1 : g:timl#nil)
  endif
endfunction

if !exists('s:empty')
  let s:empty = timl#bless('timl.lang/HashSet', {'#extra': []})
  lockvar s:empty['#extra']
  lockvar s:empty
endif
function! timl#set#empty(this) abort
  return s:empty
endfunction

function! timl#set#conj(this, ...) abort
  return timl#set#persistentb(call('timl#set#conjb', [timl#set#transient(a:this)] + a:000))
endfunction

function! timl#set#conjb(this, ...) abort
  let _ = {}
  for _.e in a:000
    let key = timl#set#key(_.e)
    if empty(key)
      let found = 0
      for i in range(len(a:this['#extra']))
        if timl#equalp(a:this['#extra'][i], _.e)
          let a:this['#extra'][i] = _.e
          let found = 1
          break
        endif
      endfor
      if !found
        call add(a:this['#extra'], _.e)
      endif
    else
      let a:this[key] = _.e
    endif
  endfor
  return a:this
endfunction

function! timl#set#disj(this, ...) abort
  return timl#set#persistentb(call('timl#set#disjb', [timl#set#transient(a:this)] + a:000))
endfunction

function! timl#set#disjb(this, ...) abort
  let _ = {}
  for _.e in a:000
    let key = timl#set#key(_.e)
    if empty(key)
      for i in range(len(a:this['#extra']))
        if timl#equalp(a:this['#extra'][i], _.e)
          call remove(a:this['#extra'], i)
          break
        endif
      endfor
    elseif has_key(a:this, key)
      call remove(a:this, key)
    endif
  endfor
  return a:this
endfunction

function! timl#set#transient(this) abort
  let that = copy(a:this)
  let that['#extra'] = copy(a:this['#extra'])
  return timl#type#bless(s:transient_type, that)
endfunction

function! timl#set#persistentb(this) abort
  let this = timl#bless(s:type, a:this)
  lockvar 1 a:this['#extra']
  lockvar 1 a:this
  return a:this
endfunction
