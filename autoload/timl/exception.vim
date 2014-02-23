" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_exception')
  finish
endif
let g:autoloaded_timl_exception = 1

let s:loctype = timl#type#core_create('Location', ['bufnr', 'filename', 'lnum',
      \ 'pattern', 'col', 'vcol', 'nr', 'text', 'type'])
let s:locproto = timl#type#bless(s:loctype,
      \ {'bufnr': 0, 'filename': '', 'lnum': 0, 'pattern': '', 'col': 0, 'vcol': 0, 'nr': 0, 'text': '', 'type': ''})
function! timl#exception#loclist(throwpoint) abort
  let list = []
  if a:throwpoint !~# '^function '
    call add(list, {"filename": matchstr(a:throwpoint, '^.\{-\}\ze\.\.')})
  endif
  for fn in split(matchstr(a:throwpoint, '\%( \|\.\.\)\zs.\{-\}\ze\%(,\|$\)'), '\.\.')
    call insert(list, copy(s:locproto))
    let list[0].text = fn
    if has_key(g:timl_functions, fn)
      let list[0].filename = g:timl_functions[fn].file
      let list[0].lnum = g:timl_functions[fn].line
    else
      try
        redir => out
        exe 'silent verbose function '.(fn =~# '^\d' ? '{'.fn.'}' : fn)
      catch
      finally
        redir END
      endtry
      if fn !~# '^\d'
        let list[0].filename = expand(matchstr(out, "\n\tLast set from \\zs[^\n]*"))
        let list[0].pattern = '^\s*fu\%[nction]!\=\s*'.substitute(fn,'^<SNR>\d\+_','s:','').'\s*('
      endif
    endif
  endfor
  return list
endfunction

let s:type = timl#type#core_create('Exception')
function! timl#exception#build(exception, throwpoint) abort
  let dict = {"exception": a:exception, "throwpoint": a:throwpoint}
  let dict.line = +matchstr(a:throwpoint, '\d\+$')
  let dict.qflist = timl#exception#loclist(a:throwpoint)
  return timl#type#bless(s:type, dict)
endfunction
