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
  let type = timl#type(a:x)
  if type == 'timl#lang#symbol'
    return a:x[0]

  elseif a:x is# g:timl#nil
    return 'nil'

  elseif timl#consp(a:x)
    let acc = []
    let _ = {'x': a:x}
    while timl#consp(_.x)
      call add(acc, timl#printer#string(timl#car(_.x)))
      let _.x = timl#cdr(_.x)
    endwhile
    if _.x isnot# g:timl#nil
      call extend(acc, ['.', timl#printer#string(_.x)])
    endif
    return '('.join(acc, ' ').')'

  elseif type(a:x) == type([])
    if timl#symbolp(get(a:x, 0, '')) && a:x[0][0] =~# '^#'
      let index = 1
      let prefix = '#'.tr(a:x[0][0][1:-1], '#', '.') . ' '
    else
      let index = 0
      let prefix = ''
    endif
    return prefix.'['.join(map(a:x[index : ], 'timl#printer#string(v:val)'), ' ') . ']'

  elseif type == 'timl#vim#dictionary'
    let acc = []
    for [k, V] in items(a:x)
      call add(acc, timl#printer#string(k) . ' ' . timl#printer#string(V))
      unlet! V
    endfor
    return '#[' . join(acc, ' ') . ']'

  elseif type == 'timl#lang#hash-set'
    let acc = []
    for [k, V] in items(a:x)
      if k !~# '^#'
        call add(acc, timl#printer#string(k) . ' ' . timl#printer#string(V))
      endif
      unlet! V
    endfor
    return '#[' . join(acc, ' ') . ']'

  elseif type(a:x) == type({})
    let acc = []
    for [k, V] in items(a:x)
      if k[0] !=# '#'
        call add(acc, timl#printer#string(timl#dekey(k)) . ' ' . timl#printer#string(V))
      endif
      unlet! V
    endfor
    let prefix = type ==# 'timl#lang#hash-map' ? '' : '#'.tr(type, '#', '.')
    return prefix.'{' . join(acc, ' ') . '}'

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
TimLPAssert timl#printer#string([1,2]) ==# '[1 2]'
TimLPAssert timl#printer#string({"a": 1, "b": 2}) ==# '#["a" 1 "b" 2]'

delcommand TimLPAssert

" }}}1

" vim:set et sw=2:
