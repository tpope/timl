" schim.vim - Schim
" Maintainer:   Tim Pope <code@tpope.net>

if exists("g:loaded_schim") || v:version < 700 || &cp
  finish
endif
let g:loaded_schim = 1

augroup schim
  autocmd!
  autocmd BufNewFile,BufReadPost *.schim iabbrev <buffer> lb λ
  autocmd BufNewFile,BufReadPost *.schim set filetype=lisp
  autocmd FuncUndefined *#* call schim#autoload(expand('<amatch>'), 'noruntime')
augroup END

command! -bar -nargs=1 -complete=file Woad :call schim#load(expand(<q-args>))
command! -bar -nargs=? Wepl :call s:repl(<f-args>)

function! s:repl(...)
  let ns = a:0 ? a:1 : 'user'
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
      let result = schim#pr_str(schim#eval([schim#symbol('begin')] + read, ns))
      echo result
    catch
      echohl ErrorMSG
      echo v:exception
      echo v:throwpoint
      echohl NONE
    endtry
    let input = input(ns.'=> ')
  endwhile
endfunction

" vim:set et sw=2:
