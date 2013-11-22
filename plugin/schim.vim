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
command! -bar Wepl :call s:repl()

function! s:repl()
  let input = input('schim> ')
  while !empty(input)
    echo "\n"
    try
      let result = schim#pr_str(schim#re(input))
      echo result
    catch
      echohl ErrorMSG
      echo v:exception
      echo v:throwpoint
      echohl NONE
    endtry
    let input = input('schim> ')
  endwhile
endfunction

" vim:set et sw=2:
