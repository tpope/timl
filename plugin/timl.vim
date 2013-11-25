" timl.vim - TimL
" Maintainer:   Tim Pope <code@tpope.net>

if exists("g:loaded_timl") || v:version < 700 || &cp
  finish
endif
let g:loaded_timl = 1

augroup timl
  autocmd!
  autocmd BufNewFile,BufReadPost *.tim set filetype=timl
  autocmd FileType timl command! -buffer -bar Wepl :update|TLsource %|TLrepl
  autocmd FuncUndefined *#* call s:autoload(expand('<amatch>'))
augroup END

command! -bar -nargs=1 -complete=file TLsource :call timl#source_file(expand(<q-args>))
command! -bar -nargs=? TLrepl :call s:repl(<f-args>)
command! -bar -nargs=1 TLload :call timl#load(<f-args>)
command! -bar -nargs=1 TLinspect :echo timl#pr_str(<args>)

if !exists('g:timl#requires')
  let g:timl#requires = {}
endif

function! s:autoload(function) abort
  let ns = matchstr(a:function, '.*\ze#')

  if !has_key(g:timl#requires, ns)
    let g:timl#requires[ns] = 1
    for file in findfile('autoload/'.tr(ns,'#','/').'.tim', &rtp, -1)
      call timl#source_file(file, ns)
    endfor
  endif
endfunction

function! s:repl(...)
  let env = {'*e': g:timl#nil, '*1': g:timl#nil}
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
            let read = timl#reader#read_string_all(input)
            break
          catch /^timl.vim: unexpected EOF/
            let input .= "\n" . input(ns.'=>> ')
            echo "\n"
          endtry
        endwhile
        let env['*1'] = timl#eval([timl#symbol('do')] + read, [env, ns, 'timl#repl', 'timl#core'])
        echo timl#pr_str(env['*1'])
      catch /^timl#repl: EXIT/
        return ''
      catch
        let env['*e'] = {'exception': v:exception, 'throwpoint': v:throwpoint}
        echohl ErrorMSG
        echo v:exception
        echohl NONE
      endtry
      let input = input(ns.'=> ')
    endwhile
  finally
    let &more = more
  endtry
endfunction

" vim:set et sw=2:
