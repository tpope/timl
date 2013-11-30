" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_printer")
  finish
endif
let g:autoloaded_timl_printer = 1

let s:escapes = {
      \ "\n": '\n',
      \ "\r": '\r',
      \ "\t": '\t',
      \ "\"": '\"',
      \ "\\": '\\'}

function! timl#printer#string(x)
  " TODO: guard against recursion
  if timl#symbolp(a:x)
    return a:x[0]
  elseif a:x is# g:timl#nil
    return 'nil'
  elseif type(a:x) == type([])
    if timl#symbolp(get(a:x, 0, '')) && a:x[0][0] =~# '^#'
      let index = 1
      let prefix = a:x[0][0]
    else
      let index = 0
      let prefix = ''
    endif
    return prefix.'('.join(map(a:x[index : ], 'timl#printer#string(v:val)'), ' ') . ')'
  elseif type(a:x) == type({})
    if timl#symbolp(get(a:x, '#tag', '')) && a:x['#tag'][0] =~# '^#'
      let prefix = a:x['#tag'][0].' '
      let skip = '#tag'
    else
      let prefix = ''
      let skip = ''
    endif
    let acc = []
    for [k, V] in items(a:x)
      if k !=# skip
        call add(acc, timl#printer#string(k) . ' ' . timl#printer#string(V))
      endif
      unlet! V
    endfor
    return prefix.'#dict(' . join(acc, ' ') . ')'
  elseif type(a:x) == type('')
    return '"'.substitute(a:x, "[\n\r\t\"\\\\]", '\=get(s:escapes, submatch(0))', 'g').'"'
  elseif type(a:x) == type(function('tr'))
    return '#*'.substitute(join([a:x]), '[{}]', '', 'g')
  else
    return string(a:x)
  endif
endfunction

" Section: Tests {{{1

if !exists('$TEST')
  finish
endif

command! -nargs=1 TimLPAssert
      \ try |
      \ if !eval(<q-args>) |
      \ echomsg "Failed: ".<q-args> |
      \   endif |
      \ catch /.*/ |
      \  echomsg "Error:  ".<q-args>." (".v:exception.")" |
      \ endtry

TimLPAssert timl#printer#string('foo') ==# '"foo"'
TimLPAssert timl#printer#string(timl#symbol('foo')) ==# 'foo'
TimLPAssert timl#printer#string([1,2]) ==# '(1 2)'
TimLPAssert timl#printer#string({"a": 1, "b": 2}) ==# '#dict("a" 1 "b" 2)'

delcommand TimLPAssert

" }}}1

" vim:set et sw=2:
