" timl.vim - TimL
" Maintainer:   Tim Pope <code@tpope.net>

if exists("g:loaded_timl") || v:version < 700 || &cp
  finish
endif
let g:loaded_timl = 1

if &maxfuncdepth == 100
  set maxfuncdepth=200
endif

augroup timl
  autocmd!
  autocmd BufNewFile,BufReadPost *.tim set filetype=timl
  autocmd FileType timl command! -buffer -bar Wepl :update|source %|TLrepl
  autocmd FileType * call s:load_filetype(expand('<amatch>'))
  autocmd SourceCmd *.tim call timl#source_file(expand("<amatch>"))
  autocmd FuncUndefined *#* call s:autoload(expand('<amatch>'))
augroup END

command! -bar -nargs=?                                             TLrepl :execute s:repl(<f-args>)
command! -nargs=1 -complete=expression                          TLinspect :echo timl#printer#string(<args>)
command! -nargs=1 -complete=customlist,timl#reflect#input_complete TLeval
      \ try |
      \    echo timl#rep(<q-args>) |
      \ catch |
      \    unlet! g:timl#core#_STAR_e |
      \    let g:timl#core#_STAR_e = timl#build_exception(v:exception, v:throwpoint) |
      \    echoerr v:exception |
      \ endtry

function! s:load_filetype(ft) abort
  let ft = split(a:ft)[0]
  for kind in ['ftplugin', 'indent']
    for file in findfile(kind.'/'.ft.'.tim', &rtp, -1)
      try
        call timl#source_file(file)
      catch
        echohl WarningMSG
        echo v:exception . ' (' . v:throwpoint .')'
        echohl NONE
      endtry
    endfor
  endfor
endfunction

if !exists('g:timl#requires')
  let g:timl#requires = {}
endif

function! s:file4ns(ns) abort
  if !exists('s:tempdir')
    let s:tempdir = tempname()
  endif
  let file = s:tempdir . '/' . a:ns . '.vim'
  if !isdirectory(fnamemodify(file, ':h'))
    call mkdir(fnamemodify(file, ':h'), 'p')
  endif
  return file
endfunction

function! s:autoload(function) abort
  let ns = tr(matchstr(a:function, '.*\ze#'), '#_', '.-')
  let base = tr(ns, '.-', '/_')

  if !has_key(g:timl#requires, ns)
    if !empty(findfile('autoload/'.base.'.vim'))
      let g:timl#requires[ns] = 1
    else
      for file in findfile('autoload/'.base.'.tim', &rtp, -1)
        call timl#source_file(file))
        let g:timl#requires[ns] = 1
        break
      endfor
    endif
  endif
  if has_key(g:, a:function) && timl#satisfiesp('timl.lang/IFn', g:{a:function})
    let body = ["function ".a:function."(...)",
          \ "  return timl#call(g:".a:function.", a:000)",
          \ "endfunction"]
    let file = s:file4ns(base)
    call writefile(body, file)
    exe 'source '.file
  endif
endfunction

function! s:repl(...) abort

  let cmpl = 'customlist,timl#reflect#input_complete'
  let more = &more
  try
    set nomore
    let guess = timl#ns_for_file(expand('%:p'))
    if !has_key(g:timl#namespaces, guess)
      let guess = 'user'
    endif
    let g:timl#core#_STAR_ns_STAR_ = g:timl#namespaces[a:0 ? a:1 : guess]
    if g:timl#core#_STAR_ns_STAR_.name == 'user'
      call timl#require('timl.repl')
      call timl#core#refer('timl.repl')
    endif
    let input = input(g:timl#core#_STAR_ns_STAR_.name.'=> ', '', cmpl)
    if input =~# '^:q\%[uit]'
      return ''
    elseif input =~# '^:'
      return input
    endif
    let _ = {}
    while !empty(input)
      echo "\n"
      try
        while 1
          try
            let read = timl#reader#read_string_all(input)
            break
          catch /^timl#reader: unexpected EOF/
            let space = repeat(' ', len(g:timl#core#_STAR_ns_STAR_.name)-2)
            let input .= "\n" . input(space.'#_=> ', '', cmpl)
            echo "\n"
          endtry
        endwhile
        let _.val = timl#eval(timl#cons(timl#symbol('do'), read), g:timl#core#_STAR_ns_STAR_.name)
        if type(_.val) != type(function('tr'))
          unlet! g:timl#core#_STAR_3
          let g:timl#core#_STAR_3 = g:timl#core#_STAR_2
          unlet! g:timl#core#_STAR_2
          let g:timl#core#_STAR_2 = g:timl#core#_STAR_1
          unlet! g:timl#core#_STAR_1
          let g:timl#core#_STAR_1 = _.val
        endif
        echo timl#printer#string(_.val)
      catch /^timl#repl: exit/
        redraw
        return v:exception[16:-1]
      catch /^Vim\%((\a\+)\)\=:E168/
        return ''
      catch
        unlet! g:timl#core#_STAR_e
        let g:timl#core#_STAR_e = timl#build_exception(v:exception, v:throwpoint)
        echohl ErrorMSG
        echo v:exception
        echohl NONE
      endtry
      let input = input(g:timl#core#_STAR_ns_STAR_.name.'=> ', '', cmpl)
    endwhile
    return input
  finally
    let &more = more
  endtry
endfunction

" vim:set et sw=2:
