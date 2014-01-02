" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_exception')
  finish
endif
let g:autoloaded_timl_exception = 1

let s:type = timl#type#intern('timl.lang/Exception')
function! timl#exception#build(exception, throwpoint)
  let dict = {"exception": a:exception, "throwpoint": a:throwpoint}
  let dict.line = +matchstr(a:throwpoint, '\d\+$')
  let dict.qflist = []
  if a:throwpoint !~# '^function '
    call add(dict.qflist, {"filename": matchstr(a:throwpoint, '^.\{-\}\ze\.\.')})
  endif
  for fn in split(matchstr(a:throwpoint, '\%( \|\.\.\)\zs.*\ze,'), '\.\.')
    call insert(dict.qflist, {'text': fn})
    if has_key(g:timl_functions, fn)
      let dict.qflist[0].filename = g:timl_functions[fn].file
      let dict.qflist[0].lnum = g:timl_functions[fn].line
    else
      try
        redir => out
        exe 'silent verbose function '.(fn =~# '^\d' ? '{'.fn.'}' : fn)
      catch
      finally
        redir END
      endtry
      if fn !~# '^\d'
        let dict.qflist[0].filename = expand(matchstr(out, "\n\tLast set from \\zs[^\n]*"))
        let dict.qflist[0].pattern = '^\s*fu\%[nction]!\=\s*'.substitute(fn,'^<SNR>\d\+_','s:','').'\s*('
      endif
    endif
  endfor
  return timl#type#bless(s:type, dict)
endfunction
