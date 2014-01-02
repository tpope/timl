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
  let type = timl#type#string(a:x)
  if type ==# 'timl.lang/Symbol'
    return a:x[0]

  elseif type ==# 'timl.lang/Keyword'
    return ':'.a:x[0]

  elseif type ==# 'timl.lang/Nil'
    return 'nil'

  elseif type ==# 'timl.lang/Boolean'
    return a:x.value ? 'true' : 'false'

  elseif type ==# 'timl.lang/Function'
    return '#<'
          \ . get(a:x, 'ns', {'name': ['...']}).name[0] . '/'
          \ . (get(a:x, 'name', g:timl#nil) is g:timl#nil ? '...' : a:x.name.name)
          \ . ' #*'.join([get(a:x, '__call__', '???')]).'>'

  elseif type ==# 'timl.lang/MultiFn'
    return '#<'
          \ . get(a:x, 'ns', {'name': ['...']}).name[0] . '/'
          \ . (get(a:x, 'name', g:timl#nil) is g:timl#nil ? '...' : a:x.name.name)
          \ . ' multi>'

  elseif type ==# 'timl.lang/Namespace'
    return '#<Namespace '.get(a:x, 'name', '')[0].'>'

  elseif type ==# 'timl.lang/Var'
    return "#'".a:x.str

  elseif type ==# 'timl.lang/Exception'
    return '#<Exception '.a:x.exception.' @ '.a:x.throwpoint.'>'

  elseif type(a:x) == type('')
    return '"'.substitute(a:x, "[\n\r\t\"\\\\]", '\=get(s:escapes, submatch(0))', 'g').'"'

  elseif timl#cons#test(a:x)
    let acc = []
    let _ = {'x': a:x}
    while _.x isnot# g:timl#nil
      call add(acc, timl#printer#string(timl#coll#first(_.x)))
      let _.x = timl#coll#next(_.x)
    endwhile
    if _.x isnot# g:timl#nil
      call extend(acc, ['.', timl#printer#string(_.x)])
    endif
    return '('.join(acc, ' ').')'

  elseif type(a:x) == type([])
    return '#*['.join(map(a:x[:], 'timl#printer#string(v:val)'), ' ') . ']'

  elseif type == 'vim/Dictionary'
    let acc = []
    for [k, V] in items(a:x)
      call add(acc, timl#printer#string(k) . ' ' . timl#printer#string(V))
      unlet! V
    endfor
    return '#*{' . join(acc, ' ') . '}'

  elseif timl#vector#test(a:x)
    return '['.join(map(timl#ary(a:x), 'timl#printer#string(v:val)'), ' ') . ']'

  elseif timl#map#test(a:x)
    let acc = []
    let _ = {'seq': timl#coll#seq(a:x)}
    while _.seq isnot# g:timl#nil
      call add(acc, timl#printer#string(timl#coll#first(_.seq))[3:-2])
      let _.seq = timl#coll#next(_.seq)
    endwhile
    return '{' . join(acc, ', ') . '}'

  elseif timl#set#test(a:x)
    let acc = []
    let _ = {'seq': timl#coll#seq(a:x)}
    while _.seq isnot# g:timl#nil
      call add(acc, timl#printer#string(timl#coll#first(_.seq)))
      let _.seq = timl#coll#next(_.seq)
    endwhile
    return '#{' . join(acc, ' ') . '}'

  elseif timl#type#canp(a:x, g:timl#core#more)
    let _ = {'seq': timl#coll#seq(a:x)}
    let output = []
    while _.seq isnot# g:timl#nil
      call add(output, timl#printer#string(timl#coll#first(_.seq)))
      let _.seq = timl#coll#next(_.seq)
    endwhile
    return '('.join(output, ' ').')'

  elseif timl#type#canp(a:x, g:timl#core#seq)
    return timl#printer#string(timl#coll#seq(a:x))

  elseif type(a:x) == type(function('tr'))
    return '#*'.substitute(join([a:x]), '[{}]', '', 'g')

  elseif type ==# 'vim/Float' && string(a:x) =~# 'n'
    if string(a:x) ==# 'inf'
      return 'Infinity'
    elseif string(a:x) ==# '-inf'
      return '-Infinity'
    else
      return 'NaN'
    endif

  elseif type =~# '^vim/'
    return string(a:x)

  else
    let acc = []
    for [k, V] in items(a:x)
      if k[0] !=# '#'
        call add(acc, k . '=' . timl#printer#string(V))
      endif
      unlet! V
    endfor
    return '#<'.type.' ' . join(acc, ', ') . '>'

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
TimLPAssert timl#printer#string(timl#vector#claim([1,2])) ==# '[1 2]'
TimLPAssert timl#printer#string({"a": 1, "b": 2}) ==# '#*{"a" 1 "b" 2}'

delcommand TimLPAssert

" }}}1

" vim:set et sw=2:
