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
  if type == 'timl.lang/Symbol'
    return a:x[0]

  elseif type == 'timl.lang/Keyword'
    return ':'.a:x[0]

  elseif a:x is# g:timl#nil
    return 'nil'

  elseif a:x is# g:timl#false
    return 'false'

  elseif a:x is# g:timl#true
    return 'true'

  elseif a:x is# g:timl#empty_list
    return '()'

  elseif type == 'timl.lang/Function'
    return '#<'.get(a:x, 'ns', '').'/'.get(a:x, 'name', '...').' '.join([a:x.call]).'>'

  elseif type == 'timl.lang/Namespace'
    return '#<Namespace '.get(a:x, 'name', '')[0].'>'

  elseif type == 'timl.lang/Type'
    return timl#str(a:x.name)

  elseif timl#consp(a:x)
    let acc = []
    let _ = {'x': a:x}
    while _.x isnot# g:timl#nil
      call add(acc, timl#printer#string(timl#first(_.x)))
      let _.x = timl#next(_.x)
    endwhile
    if _.x isnot# g:timl#nil
      call extend(acc, ['.', timl#printer#string(_.x)])
    endif
    return '('.join(acc, ' ').')'

  elseif type(a:x) == type([])
    return '['.join(map(a:x[:], 'timl#printer#string(v:val)'), ' ') . ']'

  elseif type == 'timl.vim/Dictionary'
    let acc = []
    for [k, V] in items(a:x)
      call add(acc, timl#printer#string(k) . ' ' . timl#printer#string(V))
      unlet! V
    endfor
    return '#[' . join(acc, ' ') . ']'

  elseif type == 'timl.lang/HashSet'
    let acc = []
    for [k, V] in items(a:x)
      if k !~# '^#'
        call add(acc, timl#printer#string(V))
      endif
      unlet! V
    endfor
    return '#{' . join(acc, ' ') . '}'

  elseif type !=# 'timl.vim/Dictionary' && type !=# 'timl.lang/HashMap' && timl#seqp(a:x)
    let _ = {'seq': a:x}
    let output = []
    while !empty(_.seq)
      call add(output, timl#printer#string(timl#first(_.seq)))
      let _.seq = timl#next(_.seq)
    endwhile
    return '('.join(output, ' ').')'

  elseif type !=# 'timl.vim/Dictionary' && type !=# 'timl.lang/HashMap' && timl#satisfiesp('timl.lang/Seqable', a:x)
    return timl#printer#string(timl#seq(a:x))

  elseif type(a:x) == type({})
    let acc = []
    for [k, V] in items(a:x)
      if k[0] !=# '#'
        call add(acc, timl#printer#string(timl#dekey(k)) . ' ' . timl#printer#string(V))
      endif
      unlet! V
    endfor
    let prefix = type ==# 'timl.lang/HashMap' ? '' : '#'.type
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

if !$TIML_TEST
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
