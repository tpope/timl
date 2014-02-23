" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_set")
  finish
endif
let g:autoloaded_timl_set = 1

function! timl#set#test(coll) abort
  return timl#type#canp(a:coll, g:timl#core.disj)
endfunction

function! timl#set#key(key) abort
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

function! timl#set#coerce(seq) abort
  if timl#set#test(a:seq)
    return a:seq
  endif
  let _ = {}
  let dict = timl#type#bless(s:transient_type, {'__extra': []})
  if type(a:seq) == type([])
    for _.val in a:seq
      call timl#set#conjb(dict, _.val)
    endfor
  else
    let _.seq = timl#coll#seq(a:seq)
    while _.seq isnot# g:timl#nil
      call timl#set#conjb(dict, timl#coll#first(_.seq))
      let _.seq = timl#coll#next(_.seq)
    endwhile
  endif
  return timl#set#persistentb(dict)
endfunction

function! timl#set#to_array(this) abort
  return extend(map(filter(items(a:this), 'v:val[0][0:1] !=# "__"'), 'v:val[1]'), a:this.__extra)
endfunction

function! timl#set#length(this) abort
  return len(timl#set#to_array(a:this))
endfunction

function! timl#set#seq(this) abort
  let items = timl#set#to_array(a:this)
  return empty(items) ? g:timl#nil : timl#array_seq#create(items)
endfunction

function! timl#set#equal(this, that) abort
  if a:this is# a:that
    return g:timl#true
  elseif !timl#set#test(a:that)
    return g:timl#false
  endif
  if timl#coll#count(a:this) !=# timl#coll#count(a:that)
    return g:timl#false
  endif
  let _ = {'seq': timl#coll#seq(a:this)}
  while _.seq isnot# g:timl#nil
    if timl#coll#get(a:that, timl#coll#first(_.seq), _) is# _
      return g:timl#false
    endif
    let _.seq = timl#coll#next(_.seq)
  endwhile
  return g:timl#true
endfunction

function! timl#set#lookup(this, key, ...) abort
  let _ = {}
  let key = timl#set#key(a:key)
  if empty(key)
    for _.v in a:this.__extra
      if timl#equality#test(_.v, a:key)
        return _.v
      endif
    endfor
    return a:0 ? a:1 g:timl#nil
  else
    return get(a:this, key, a:0 ? a:1 : g:timl#nil)
  endif
endfunction

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
      for i in range(len(a:this.__extra))
        if timl#equality#test(a:this.__extra[i], _.e)
          let a:this.__extra[i] = _.e
          let found = 1
          break
        endif
      endfor
      if !found
        call add(a:this.__extra, _.e)
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
      for i in range(len(a:this.__extra))
        if timl#equality#test(a:this.__extra[i], _.e)
          call remove(a:this.__extra, i)
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
  let that.__extra = copy(a:this.__extra)
  return timl#type#bless(s:transient_type, that)
endfunction

function! timl#set#persistentb(this) abort
  let this = timl#type#bless(s:type, a:this)
  lockvar 1 a:this.__extra
  lockvar 1 a:this
  return a:this
endfunction

function! timl#set#call(this, _) abort
  return call('timl#set#lookup', [a:this] + a:_)
endfunction

let s:type = timl#type#core_define('HashSet', g:timl#nil, {
      \ 'seq': 'timl#set#seq',
      \ 'lookup': 'timl#set#lookup',
      \ 'empty': 'timl#set#empty',
      \ 'conj': 'timl#set#conj',
      \ 'length': 'timl#set#length',
      \ 'equiv': 'timl#set#equal',
      \ 'disj': 'timl#set#disj',
      \ 'transient': 'timl#set#transient',
      \ 'call': 'timl#set#call'})

let s:transient_type = timl#type#core_define('TransientHashSet', g:timl#nil, {
      \ 'length': 'timl#set#length',
      \ 'lookup': 'timl#set#lookup',
      \ 'conj!': 'timl#set#conjb',
      \ 'disj!': 'timl#set#disjb',
      \ 'persistent!': 'timl#set#persistentb'})

if !exists('s:empty')
  let s:empty = timl#type#bless(s:type, {'__extra': []})
  lockvar 1 s:empty.__extra
  lockvar 1 s:empty
endif
