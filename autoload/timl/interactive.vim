" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_interactive')
  finish
endif
let g:autoloaded_timl_interactive = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

function! s:lencompare(a, b) abort
  return len(a:b) - len(a:b)
endfunction

function! timl#interactive#ns_for_file(file) abort
  let file = fnamemodify(a:file, ':p')
  let candidates = []
  for glob in split(&runtimepath, ',')
    let candidates += filter(split(glob(glob), "\n"), 'file[0 : len(v:val)-1] ==# v:val && file[len(v:val)] =~# "[\\/]"')
  endfor
  if empty(candidates)
    return 'user'
  endif
  let dir = sort(candidates, s:function('s:lencompare'))[-1]
  let path = file[len(dir)+1 : -1]
  return substitute(tr(fnamemodify(path, ':r:r'), '\/_', '..-'), '^\%(autoload\|plugin\|test\).', '', '')
endfunction

function! timl#interactive#ns_for_cursor(...) abort
  call timl#loader#init()
  let pattern = '\c(\%(in-\)\=ns\s\+''\=[[:alpha:]]\@='
  let line = 0
  if !a:0 || a:1
    let line = search(pattern, 'bcnW')
  endif
  if !line
    let i = 1
    while i < line('$') && i < 100
      if getline(i) =~# pattern
        let line = i
        break
      endif
      let i += 1
    endwhile
  endif
  if line
    let ns = matchstr(getline(line), pattern.'\zs[[:alnum:]._-]\+')
  else
    let ns = timl#interactive#ns_for_file(expand('%:p'))
  endif
  if !exists('g:autoloaded_timl_loader')
    runtime! autoload/timl/loader.vim
  endif
  let nsobj = timl#namespace#find(timl#symbol(ns))
  if nsobj isnot# g:timl#nil
    return ns
  else
    return 'user'
  endif
endfunction

function! timl#interactive#eval_opfunc(type) abort
  let selection = &selection
  let clipboard = &clipboard
  let reg = @@
  try
    set selection=inclusive clipboard=
    if a:0
      silent exe "normal! `<" . a:type . "`>y"
    elseif a:type == 'line'
      silent exe "normal! '[V']y"
    elseif a:type == 'block'
      silent exe "normal! `[\<C-V>`]y"
    else
      silent exe "normal! `[v`]y"
    endif
    let string = @@
  finally
    let &selection = selection
    let &clipboard = clipboard
    let @@ = reg
  endtry
  let port = timl#reader#open_string(string, expand('%:p'), line("'["))
  try
    echo timl#printer#string(timl#loader#consume(port))
  catch //
    echohl ErrorMsg
    echo v:exception
    echohl NONE
    unlet! g:timl#core#_STAR_e
    let g:timl#core#_STAR_e = timl#compiler#build_exception(v:exception, v:throwpoint)
  finally
    call timl#reader#close(port)
  endtry
endfunction

function! timl#interactive#omnicomplete(findstart, base) abort
  if a:findstart
    let line = getline('.')[0 : col('.')-2]
    return col('.') - strlen(matchstr(line, '\k\+$')) - 1
  endif
  let results = []
  let ns = timl#interactive#ns_for_cursor()
  if timl#namespace#find(ns) is g:timl#nil
    let ns = 'user'
  endif
  let results = map(keys(timl#namespace#find(ns).mappings), '{"word": v:val}')
  return filter(results, 'v:val.word[0] !=# "#" && (a:base ==# "" || a:base ==# v:val.word[0 : strlen(a:base)-1])')
endfunction

function! timl#interactive#input_complete(A, L, P) abort
  let prefix = matchstr(a:A, '\%(.* \|^\)\%(#\=[\[{('']\)*')
  let keyword = a:A[strlen(prefix) : -1]
  return sort(map(timl#interactive#omnicomplete(0, keyword), 'prefix . v:val.word'))
endfunction
