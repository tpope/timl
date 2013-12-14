if exists("g:autoloaded_timl_vim")
  finish
endif
let g:autoloaded_timl_vim = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

function! s:implement(type, ...)
  let type = timl#keyword#intern(a:type)
  for i in range(0, a:0-1, 2)
    call timl#type#define_method('timl.core', a:000[i], type, a:000[i+1])
  endfor
endfunction

" Section: String

" Characters, not bytes
function! s:string_lookup(this, idx, default) abort
  if type(a:idx) == type(0)
    let ch = matchstr(a:this, repeat('.', a:idx).'\zs.')
    return empty(ch) ? (a:0 ? a:1 : g:timl#nil) : ch
  endif
  return a:default
endfunction

function! s:string_count(this) abort
  return exists('*strchars') ? strchars(a:this) : len(substitute(a:this, '.', '.', 'g'))
endfunction

call s:implement('vim/String',
      \ 'lookup', s:function('s:string_lookup'),
      \ 'count', s:function('s:string_count'))

" Section: Funcref

function! s:funcall(this, args)
  return call(a:this, a:args, {'__fn__': a:this})
endfunction

call s:implement('vim/Funcref', '_invoke', s:function('s:funcall'))

" Section: List

function! s:list_seq(this) abort
  return empty(a:this) ? g:timl#nil : timl#array_seq#create(a:this)
endfunction

function! s:list_first(this) abort
  return get(a:this, 0, g:timl#nil)
endfunction

function! s:list_rest(this) abort
  return len(a:this) <= 1 ? g:timl#empty_list : timl#array_seq#create(a:this, 1)
endfunction

function! s:list_lookup(this, idx, ...) abort
  if type(a:idx) == type(0)
    return get(a:this, a:idx, a:0 ? a:1 g:timl#nil)
  endif
  return a:0 ? a:1 : g:timl#nil
endfunction

function! s:list_nth(this, idx, ...) abort
  let idx = timl#int(a:idx)
  if a:0
    return get(a:this, idx, a:1)
  else
    return a:this[idx]
  endif
endfunction

function! s:list_cons(this, ...) abort
  return timl#persistentb(a:this + a:000)
endfunction

function! s:list_empty(this) abort
  let this = a:this
  let empty = []
  if islocked('this')
    lockvar 1 empty
  endif
  return this
endfunction

call s:implement('vim/List',
      \ 'seq', s:function('s:list_seq'),
      \ 'first', s:function("s:list_first"),
      \ 'more', s:function("s:list_rest"),
      \ 'lookup', s:function('s:list_lookup'),
      \ 'nth', s:function('s:list_nth'),
      \ 'count', s:function('len'),
      \ 'conj', s:function('s:list_cons'),
      \ 'empty', s:function('s:list_empty'),
      \ '_invoke', s:function('s:list_lookup'))

" vim:set et sw=2:
