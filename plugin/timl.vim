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
  autocmd BufNewFile,BufReadPost *
        \ if getline(1) =~# '^#!' && getline(2) =~# ';.*\<TL' |
        \   set filetype=timl |
        \ endif
  autocmd FileType timl command! -buffer -bar Wepl
        \ update |
        \ execute 'TLsource %' |
        \ set filetype=timl |
        \ redraw! |
        \ call timl#interactive#repl(timl#interactive#ns_for_cursor())
  autocmd FileType * call s:load_filetype(expand('<amatch>'))
  autocmd SourceCmd *.tim call timl#loader#source(expand("<amatch>"))
  autocmd FuncUndefined *#* call s:autoload(expand('<amatch>'))
  autocmd VimEnter * nested
        \ if exists('s:source') |
        \   redraw! |
        \   execute 'TLsource '.s:source |
        \   unlet! s:source |
        \ endif
augroup END

command! -bar -nargs=?                    TLrepl :execute timl#interactive#repl(<f-args>)
command! -bar                          TLscratch :execute timl#interactive#scratch()
command! -nargs=1 -complete=expression TLinspect :echo timl#printer#string(<args>)
command! -nargs=1 -complete=customlist,timl#interactive#input_complete TLeval
      \ try |
      \    echo timl#rep(<q-args>) |
      \ catch |
      \    unlet! g:timl#core._STAR_e |
      \    let g:timl#core._STAR_e = timl#exception#build(v:exception, v:throwpoint) |
      \    echoerr v:exception |
      \ endtry
command! -bar TLcopen :call timl#interactive#copen(get(g:, 'timl#core#_STAR_e', []))
command! -bang -nargs=? -complete=file TLsource
      \ if has('vim_starting') |
      \   let s:source = <q-args> |
      \ else |
      \   call timl#loader#source(expand(empty(<q-args>) ? '%' : <q-args>)) |
      \ endif

function! s:load_filetype(ft) abort
  if empty(a:ft)
    return ''
  endif
  let ft = split(a:ft)[0]
  for kind in ['ftplugin', 'indent']
    for file in findfile(kind.'/'.ft.'.tim', &rtp, -1)
      try
        call timl#loader#source(file)
      catch
        unlet! g:timl#core._STAR_e
        let g:timl#core._STAR_e = timl#exception#build(v:exception, v:throwpoint) |
        echohl WarningMSG
        echomsg v:exception
        echohl NONE
      endtry
    endfor
  endfor
endfunction

if !exists('g:timl_requires')
  let g:timl_requires = {}
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

  if !has_key(g:timl_requires, ns)
    if !empty(findfile('autoload/'.base.'.vim'))
      let g:timl_requires[ns] = 1
    else
      for file in findfile('autoload/'.base.'.tim', &rtp, -1)
        call timl#loader#source(file)
        let g:timl_requires[ns] = 1
        break
      endfor
    endif
  endif
  if has_key(g:, a:function) && timl#type#canp(g:{a:function}, g:timl#core.call)
    let body = ["function ".a:function."(...)",
          \ "  return timl#call(g:".a:function.", a:000)",
          \ "endfunction"]
    let file = s:file4ns(base)
    call writefile(body, file)
    exe 'source '.file
  endif
endfunction
