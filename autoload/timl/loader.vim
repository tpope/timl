" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_loader')
  finish
endif
let g:autoloaded_timl_loader = 1

function! timl#loader#eval(x) abort
  return timl#compiler#build(a:x).call()
endfunction

function! timl#loader#consume(port) abort
  let _ = {'result': g:timl#nil}
  let eof = []
  let _.read = timl#reader#read(a:port, eof)
  while _.read isnot# eof
    let _.result = timl#compiler#build(_.read, get(a:port, 'filename', 'NO_SOURCE_PATH')).call()
    let _.read = timl#reader#read(a:port, eof)
  endwhile
  return _.result
endfunction

let s:dir = (has('win32') ? '$APPCACHE/Vim' :
      \ match(system('uname'), "Darwin") > -1 ? '~/Library/Vim' :
      \ empty($XDG_CACHE_HOME) ? '~/.cache/vim' : '$XDG_CACHE_HOME/vim').'/timl'

function! s:cache_filename(path) abort
  let base = expand(s:dir)
  if !isdirectory(base)
    call mkdir(base, 'p')
  endif
  let filename = tr(substitute(fnamemodify(a:path, ':~'), '^\~.', '', ''), '\/:', '%%%') . '.vim'
  return base . '/' . filename
endfunction

let s:myftime = getftime(expand('<sfile>'))

if !exists('g:timl_functions')
  let g:timl_functions = {}
endif

function! timl#loader#source(filename) abort
  let path = fnamemodify(a:filename, ':p')
  let old_ns = g:timl#core._STAR_ns_STAR_
  let cache = s:cache_filename(path)
  try
    let g:timl#core._STAR_ns_STAR_ = timl#namespace#find(timl#symbol#intern('user'))
    let ftime = getftime(cache)
    if !exists('$TIML_EXPIRE_CACHE') && ftime > getftime(path) && ftime > s:myftime
      try
        execute 'source '.fnameescape(cache)
      catch
        let error = v:exception
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
      call add(strs, "function! s:d.f() abort\nlet locals = {}\n".obj.body."endfunction\n")
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
    let g:timl#core._STAR_ns_STAR_ = old_ns
    if exists('file')
      call timl#reader#close(file)
    endif
  endtry
endfunction

function! timl#loader#relative(path) abort
  if !empty(findfile('autoload/'.a:path.'.vim', &rtp))
    execute 'runtime! autoload/'.a:path.'.vim'
    return g:timl#nil
  endif
  for file in findfile('autoload/'.a:path.'.tim', &rtp, -1)
    call timl#loader#source(file)
    return g:timl#nil
  endfor
  throw 'timl: could not load '.a:path
endfunction

function! timl#loader#all_relative(paths) abort
  for path in timl#array#coerce(a:paths)
    if path[0] ==# '/'
      let path = path[1:-1]
    else
      let path = substitute(tr(timl#namespace#name(g:timl#core._STAR_ns_STAR_).str, '.-', '/_'), '[^/]*$', '', '') . path
    endif
    call timl#loader#relative(path)
  endfor
  return g:timl#nil
endfunction

if !exists('g:timl_requires')
  let g:timl_requires = {}
endif

function! timl#loader#require(ns, ...) abort
  let ns = timl#symbol#cast(a:ns).name
  if !has_key(g:timl_requires, ns) || a:0 && a:1
    call timl#loader#relative(tr(ns, '.-', '/_'))
    let g:timl_requires[ns] = 1
  endif
endfunction

let s:k_reload = timl#keyword#intern('reload')
let s:k_as = timl#keyword#intern('as')
let s:k_refer = timl#keyword#intern('refer')
let s:k_all = timl#keyword#intern('all')
let s:k_only = timl#keyword#intern('only')
function! timl#loader#require_all(_) abort
  let _ = {}
  let reload = 0
  for option in filter(copy(a:_), 'timl#keyword#test(v:val)')
    if option is# s:k_reload
      let reload = 1
    else
      throw 'timl#loader: unsupported require option :'.option[0]
    endif
  endfor
  for _.spec in a:_
    if timl#symbol#test(_.spec)
      call timl#loader#require(_.spec, reload)
    elseif timl#vector#test(_.spec)
      let _.lib = timl#coll#first(_.spec)
      call timl#loader#require(_.lib, reload)
      if timl#coll#fnext(_.spec) is# s:k_as
        call timl#namespace#alias(timl#coll#first(timl#coll#nnext(_.spec)), _.lib)
      elseif timl#coll#fnext(_.spec) is# s:k_refer
        let _.qualifier = timl#coll#first(timl#coll#nnext(_.spec))
        if _.qualifier is# s:k_all
          call timl#namespace#refer(_.lib)
        else
          call timl#namespace#refer(_.lib, s:k_only, _.qualifier)
        endif
      endif
    elseif !timl#keyword#test(_.spec)
      throw 'timl#loader: invalid loading spec type '.timl#type#string(_.spec)
    endif
  endfor
  return g:timl#nil
endfunction

function! timl#loader#use_all(_) abort
  let _ = {}
  for _.spec in a:_
    call timl#loader#require(_.spec)
    return timl#namespace#refer(_.spec)
  endfor
endfunction

function! timl#loader#init() abort
endfunction

if !exists('g:autoloaded_timl_bootstrap')
  runtime! autoload/timl/bootstrap.vim
endif

let s:core = timl#namespace#create(timl#symbol#intern('timl.core'))
let s:user = timl#namespace#create(timl#symbol#intern('user'))
call timl#namespace#intern(s:core, timl#symbol#intern('*ns*'), s:user)
let s:user.__mappings__['in-ns'] = s:core.__mappings__['in-ns']
call timl#loader#require(timl#symbol#intern('timl.core'))
call timl#namespace#refer(timl#symbol#intern('timl.core'))

" vim:set et sw=2:
