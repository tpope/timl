" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_loader')
  finish
endif
unlet! g:autoloaded_timl_loader

function! timl#loader#eval(x) abort
  return timl#compiler#build(a:x).call()
endfunction

let s:dir = (has('win32') ? '$APPCACHE/Vim' :
      \ match(system('uname'), "Darwin") > -1 ? '~/Library/Vim' :
      \ empty($XDG_CACHE_HOME) ? '~/.cache/vim' : '$XDG_CACHE_HOME/vim').'/timl'

function! s:cache_filename(path)
  let base = expand(s:dir)
  if !isdirectory(base)
    call mkdir(base, 'p')
  endif
  let filename = tr(substitute(fnamemodify(a:path, ':~'), '^\~.', '', ''), '\/:', '%%%') . '.vim'
  return base . '/' . filename
endfunction

let s:myftime = getftime(expand('<sfile>'))

function! timl#loader#source(filename)
  let path = fnamemodify(a:filename, ':p')
  let old_ns = g:timl#core#_STAR_ns_STAR_
  let cache = s:cache_filename(path)
  try
    let g:timl#core#_STAR_ns_STAR_ = timl#namespace#find(timl#symbol('user'))
    let ftime = getftime(cache)
    if !exists('$TIML_EXPIRE_CACHE') && ftime > getftime(path) && ftime > s:myftime
      try
        execute 'source '.fnameescape(cache)
      catch
        let error = 1
      endtry
      if !exists('error')
        return
      endif
    endif
    let file = timl#reader#open(path)
    let strs = ["let s:d = {}"]
    let _ = {}
    let _.read = g:timl#nil
    let eof = []
    while _.read isnot# eof
      let _.read = timl#reader#read(file, eof)
      let obj = timl#compiler#build(_.read, path)
      call obj.call()
      call add(strs, "function! s:d.f() abort\nlet locals = {}\nlet temp = {}\n".obj.body."endfunction\n")
      let meta = timl#compiler#location_meta(path, _.read)
      if !empty(meta)
        let strs[-1] .= 'let g:timl_functions[join([s:d.f])] = '.string(meta)."\n"
      endif
      let strs[-1] .= "call s:d.f()\n"
    endwhile
    call add(strs, 'unlet s:d')
    call writefile(split(join(strs, "\n"), "\n"), cache)
  catch /^Vim\%((\a\+)\)\=:E168/
  finally
    let g:timl#core#_STAR_ns_STAR_ = old_ns
    if exists('file')
      call timl#reader#close(file)
    endif
  endtry
endfunction

let s:core = timl#namespace#create(timl#symbol#intern('timl.core'))
let s:user = timl#namespace#create(timl#symbol#intern('user'))
call timl#namespace#intern(s:core, timl#symbol#intern('*ns*'), s:user)
let s:user.mappings['in-ns'] = s:core.mappings['in-ns']
call timl#require('timl.core')
call timl#namespace#refer(timl#symbol('timl.core'))

" vim:set et sw=2:
