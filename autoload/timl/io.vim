" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_io")
  finish
endif
let g:autoloaded_timl_io = 1

function! timl#io#echon(_) abort
  echon join(map(copy(a:_), 'timl#string#coerce(v:val)'), ' ')
  return g:timl#nil
endfunction

function! timl#io#echo(_) abort
  echo join(map(copy(a:_), 'timl#string#coerce(v:val)'), ' ')
  return g:timl#nil
endfunction

function! timl#io#echomsg(_) abort
  echomsg join(map(copy(a:_), 'timl#string#coerce(v:val)'), ' ')
  return g:timl#nil
endfunction

function! timl#io#println(_) abort
  echon join(map(copy(a:_), 'timl#string#coerce(v:val)'), ' ')."\n"
  return g:timl#nil
endfunction

function! timl#io#newline() abort
  echon "\n"
  return g:timl#nil
endfunction

function! timl#io#printf(fmt, ...) abort
  echon call('printf', [timl#string#coerce(a:fmt)] + a:000)."\n"
  return g:timl#nil
endfunction

function! timl#io#pr(_) abort
  echon join(map(copy(a:_), 'timl#printer#string(v:val)'), ' ')
  return g:timl#nil
endfunction

function! timl#io#prn(_) abort
  echon join(map(copy(a:_), 'timl#printer#string(v:val)'), ' ')."\n"
  return g:timl#nil
endfunction

function! timl#io#spit(filename, body) abort
  if type(body) == type([])
    call writefile(body, a:filename)
  else
    call writefile(split(body, "\n"), a:filename, 'b')
endfunction

function! timl#io#slurp(filename) abort
  return join(readfile(a:filename, 'b'), "\n")
endfunction
