" timl.vim - TimL
" Maintainer:   Tim Pope <code@tpope.net>

if exists("g:loaded_timl") || v:version < 700 || &cp
  finish
endif
let g:loaded_timl = 1

augroup timl
  autocmd!
  autocmd SourceCmd *.tim call timl#source_file(expand("<amatch>"))
  autocmd BufNewFile,BufReadPost *.tim set filetype=timl
  autocmd FileType timl command! -buffer -bar Wepl :update|TLsource %|TLrepl
  autocmd FuncUndefined *#* call s:autoload(expand('<amatch>'))
augroup END

command! -bar -nargs=1 -complete=file TLsource :call timl#source_file(expand(<q-args>))
command! -bar -nargs=? TLrepl :call s:repl(<f-args>)
command! -bar -nargs=1 TLload :call timl#load(<f-args>)
command! -bar -nargs=1 -complete=expression TLinspect :echo timl#pr_str(<args>)

if !exists('g:timl#requires')
  let g:timl#requires = {}
endif

function! s:autoload(function) abort
  let ns = matchstr(a:function, '.*\ze#')

  if !has_key(g:timl#requires, ns)
    let g:timl#requires[ns] = 1
    execute 'runtime! autoload/'.tr(ns, '#', '/').'.tim'
    " for file in findfile('autoload/'.tr(ns,'#','/').'.tim', &rtp, -1)
    "   call timl#source_file(file, ns)
    " endfor
  endif
endfunction

function! s:repl(...)
  let cmpl = 'customlist,timl#reflect#input_complete'
  let env = {'*e': g:timl#nil, '*1': g:timl#nil}
  let more = &more
  try
    set nomore
    let g:timl#core#_STAR_ns_STAR_ = a:0 ? a:1 : timl#ns_for_file(expand('%:p'))
    let input = input(g:timl#core#_STAR_ns_STAR_.'=> ', '', cmpl)
    while !empty(input)
      echo "\n"
      try
        while 1
          try
            let read = timl#reader#read_string_all(input)
            break
          catch /^timl.vim: unexpected EOF/
            let space = repeat(' ', len(g:timl#core#_STAR_ns_STAR_)-2)
            let input .= "\n" . input(space.'#_=> ', '', cmpl)
            echo "\n"
          endtry
        endwhile
        let env['*1'] = timl#eval([timl#symbol('do')] + read, [env, g:timl#core#_STAR_ns_STAR_, 'timl#repl'])
        echo timl#pr_str(env['*1'])
      catch /^timl#repl: EXIT/
        return ''
      catch
        let env['*e'] = {'exception': v:exception, 'throwpoint': v:throwpoint}
        echohl ErrorMSG
        echo v:exception
        echohl NONE
      endtry
      let input = input(g:timl#core#_STAR_ns_STAR_.'=> ', '', cmpl)
    endwhile
  finally
    let &more = more
  endtry
endfunction

" vim:set et sw=2:
