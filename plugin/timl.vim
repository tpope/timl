" timl.vim - TimL
" Maintainer:   Tim Pope <code@tpope.net>

if exists("g:loaded_timl") || v:version < 700 || &cp
  finish
endif
let g:loaded_timl = 1

augroup timl
  autocmd!
  autocmd BufNewFile,BufReadPost *.tim set filetype=timl
  autocmd FuncUndefined *#* call s:autoload(expand('<amatch>'))
augroup END

command! -bar -nargs=1 -complete=file TLsource :call timl#source(expand(<q-args>))
command! -bar -nargs=? TLrepl :call s:repl(<f-args>)
command! -bar -nargs=1 TLload :call timl#load(<f-args>)

if !exists('g:timl#requires')
  let g:timl#requires = {}
endif

function! s:autoload(function) abort
  let ns = matchstr(a:function, '.*\ze#')

  if !has_key(g:timl#requires, ns)
    let g:timl#requires[ns] = 1
    for file in findfile('autoload/'.tr(ns,'#','/').'.tim', &rtp, -1)
      call timl#source(file, ns)
    endfor
  endif
endfunction

function! s:repl(...)
  let more = &more
  try
    set nomore
    let ns = a:0 ? a:1 : timl#ns_for_file(expand('%:p'))
    let input = input(ns.'=> ')
    while !empty(input)
      echo "\n"
      try
        while 1
          try
            let read = timl#read_all(input)
            break
          catch /^timl.vim: unexpected EOF/
            let input .= "\n" . input(ns.'=>> ')
            echo "\n"
          endtry
        endwhile
        let result = timl#pr_str(timl#eval([timl#symbol('do')] + read, ns))
        echo result
      catch
        echohl ErrorMSG
        echo v:exception
        echo v:throwpoint
        echohl NONE
      endtry
      let input = input(ns.'=> ')
    endwhile
  finally
    let &more = more
  endtry
endfunction

" vim:set et sw=2:
