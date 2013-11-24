" schim.vim - Schim
" Maintainer:   Tim Pope <code@tpope.net>

if exists("g:loaded_schim") || v:version < 700 || &cp
  finish
endif
let g:loaded_schim = 1

augroup schim
  autocmd!
  autocmd BufNewFile,BufReadPost *.tim set filetype=timl
  autocmd FuncUndefined *#* call s:autoload(expand('<amatch>'))
augroup END

command! -bar -nargs=1 -complete=file TLsource :call schim#source(expand(<q-args>))
command! -bar -nargs=? TLrepl :call s:repl(<f-args>)
command! -bar -nargs=1 TLload :call schim#load(<f-args>)

if !exists('g:schim#requires')
  let g:schim#requires = {}
endif

function! s:autoload(function) abort
  let ns = matchstr(a:function, '.*\ze#')

  if !has_key(g:schim#requires, ns)
    let g:schim#requires[ns] = 1
    for file in findfile('autoload/'.tr(ns,'#','/').'.tim', &rtp, -1)
      call schim#source(file, ns)
    endfor
  endif
endfunction

function! s:repl(...)
  let more = &more
  try
    set nomore
    let ns = a:0 ? a:1 : schim#ns_for_file(expand('%:p'))
    let input = input(ns.'=> ')
    while !empty(input)
      echo "\n"
      try
        while 1
          try
            let read = schim#read_all(input)
            break
          catch /^schim.vim: unexpected EOF/
            let input .= "\n" . input(ns.'=>> ')
            echo "\n"
          endtry
        endwhile
        let result = schim#pr_str(schim#eval([schim#symbol('do')] + read, ns))
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
