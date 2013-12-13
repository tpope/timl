" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_reader")
  finish
endif
let g:autoloaded_timl_reader = 1

let s:iskeyword = '[[:alnum:]_=?!#$%&*+|./<>:-]'

function! s:read_token(port) abort
  let pat = '^\%(#"\%(\\\@<!\%(\\\\\)*\\"\|[^"]\)*"\|#[[:punct:]]\|"\%(\\.\|[^"]\)*"\|[[:space:],]\+\|;[^'."\n".']*\|\~@\|'.s:iskeyword.'\+\|\\\%(space\|tab\|newline\|return\|.\)\|.\)'
  let match = ' '
  while match =~# '^[[:space:],]'
    let [pos, line] = [a:port.pos, a:port.line]
    let match = matchstr(a:port.str, pat, a:port.pos)
    let a:port.pos += len(match)
    let a:port.line += len(substitute(match, "[^\n]", '', 'g'))
  endwhile
  return [match, pos, line]
endfunction

function! timl#reader#eofp(port)
  return a:port.pos >= len(a:port.str)
endfunction

let g:timl#reader#eof = []

function! timl#reader#read(port, ...) abort
  let error = 'timl#reader: EOF'
  try
    let val = s:read(a:port)
    if val isnot# g:timl#reader#eof
      return val
    elseif a:0
      return a:1
    endif
  catch /^timl.*/
    let error = v:exception
  endtry
  throw error
endfunction

let s:found = {}
function! s:read_until(port, char)
  let list = []
  let _ = {}
  let _.read = s:read(a:port, a:char)
  while _.read isnot# s:found && _.read isnot# g:timl#reader#eof
    call add(list, _.read)
    let _.read = s:read(a:port, a:char)
  endwhile
  if _.read is# s:found
    lockvar 1 list
    return list
  endif
  throw 'timl#reader: EOF'
endfunction

let s:constants = {
      \ '\space': " ",
      \ '\tab': "\t",
      \ '\newline': "\n",
      \ '\return': "\r"}

function! s:add_meta(data, meta) abort
  let data = a:data
  if timl#symbol#test(data)
    let data = copy(data)
  else
    unlockvar 1 data
  endif
  if !has_key(data, '#meta')
    let data['#meta'] = timl#hash_map()
  endif
  unlockvar 1 data['#meta']
  call extend(data['#meta'], a:meta)
  lockvar 1 data['#meta']
  lockvar 1 data
  return data
endfunction

function! s:read(port, ...) abort
  let port = a:port
  let [token, pos, line] = s:read_token(a:port)
  let data = s:process(a:port, token, line, a:0 ? a:1 : ' ')
  if has_key(a:port, 'filename') && timl#consp(data)
    return s:add_meta(data, {'file': a:port.filename, 'line': line})
  endif
  return data
endfunction

function! s:process(port, token, line, wanted) abort
  let port = a:port
  let token = a:token
  let line = a:line
  if token ==# '('
    return timl#list2(s:read_until(port, ')'))
  elseif token == '['
    return timl#vec(s:read_until(port, ']'))
  elseif token == '{'
    let list = s:read_until(port, '}')
    if len(list) % 2 != 0
      let error = 'timl#reader: invalid hash map literal'
    else
      return timl#hash_map(list)
    endif
  elseif token == '#['
    let list = s:read_until(port, ']')
    if len(list) % 2 != 0
      let error = 'timl#reader: invalid dict literal'
    else
      let dict = {}
      for i in range(0, len(list)-1, 2)
        if type(list[i]) !=# type("")
          let error = 'timl#reader: dict keys must be strings'
          break
        endif
        let dict[list[i]] = list[i+1]
      endfor
    endif
    if !exists('error')
      lockvar 1 dict
      return dict
    endif
  elseif token == '#{'
    return timl#set(s:read_until(port, '}'))
  elseif has_key(s:constants, token)
    return s:constants[token]
  elseif token ==# 'nil'
    return g:timl#nil
  elseif token ==# 'false'
    return g:timl#false
  elseif token ==# 'true'
    return g:timl#true
  elseif token =~# '^\d\+e\d\+$'
    return eval(substitute(token, 'e', '.0e', ''))
  elseif token =~# '^\.\d'
    return eval('0'.token)
  elseif token =~# '^"\|^[+-]\=\d\%(.*\d\)\=$'
    return eval(token)
  elseif token =~# '^#"'
    return substitute(token[2:-2], '\\\@<!\(\%(\\\\\)*\)\\"', '\1"', 'g')
  elseif token[0] ==# '\'
    return token[1]
  elseif token ==# "'"
    return timl#list(timl#symbol('quote'), s:read_bang(port))
  elseif token ==# '`'
    return timl#reader#syntax_quote(s:read_bang(port), {})
  elseif token ==# '~'
    return timl#list(s:unquote, s:read_bang(port))
  elseif token ==# '~@'
    return timl#list(s:unquote_splicing, s:read_bang(port))
  elseif token ==# '#*'
    return timl#list(timl#symbol('function'), s:read_bang(port))
  elseif token[0] ==# ';'
    return s:read(port, a:wanted)
  elseif token ==# '#_'
    call s:read(port)
    return s:read(port, a:wanted)
  elseif token ==# '#('
    if has_key(port, 'argsyms')
      throw "timl#reader: can't nest #()"
    endif
    try
      let port.argsyms = {}
      let list = s:read_until(port, ')')
      let rest = has_key(port.argsyms, '%&')
      let args = map(range(1, len(port.argsyms) - rest), 'port.argsyms["%".v:val]')
      if rest
        call add(args, a:port.argsyms['%&'])
      endif
      return timl#list(timl#symbol('fn*'), args, timl#list2(list))
    finally
      unlet! a:port.argsyms
    endtry
  elseif token =~# '^%\d*$\|^%&$' && has_key(port, 'argsyms')
    let token = (token ==# '%' ? '%1' : token)
    if !has_key(port.argsyms, token)
      let port.argsyms[token] = timl#gensym('p1__')
    endif
    return port.argsyms[token]
  elseif token =~# '^#\a'
    let next = s:read(port)
    unlockvar 1 next
    let token = token[1:-1]
    if token !~# '[/.]'
      let token = 'timl.lang/'.token
    endif
    if type(next) == type({})
      return timl#bless(token, next)
    else
      return timl#bless(token, {'value': next})
    endif
  elseif token =~# '^::.\+/.'
    let alias = matchstr(token[2:-1], '.*\ze/.')
    let ns = get(g:timl#core#_STAR_ns_STAR_.aliases, alias, {})
    if empty(ns)
      let error = 'timl#reader: unknown ns alias '.alias.' in keyword'
    else
      return timl#keyword#intern(timl#the_ns(ns).name[0].matchstr(token, '.*\zs/.\+'))
    endif
  elseif token =~# '^::.'
    return timl#keyword#intern(g:timl#core#_STAR_ns_STAR_.name[0].'/'.token[2:-1])
  elseif token =~# '^:.'
    return timl#keyword#intern(token[1:-1])
  elseif token =~# '^'.s:iskeyword
    return timl#symbol(token)
  elseif token ==# '^'
    let _meta = s:read(port)
    let data = s:read(port)
    if timl#keyword#test(_meta)
      let meta = {_meta[0]: g:timl#true}
    elseif timl#symbol#test(_meta) || type(_meta) == type('')
      let meta = {'tag': _meta}
    elseif timl#mapp(_meta)
      let meta = _meta
    else
      throw 'timl#reader: metadata must be symbol, string, keyword, or map'
    endif
    if timl#type#objectp(data)
      return s:add_meta(data, meta)
    endif
    return data
    let error = 'timl#reader: cannot attach metadata to a '.timl#type#string(data)
  elseif token ==# '@'
    return timl#list(timl#symbol('timl.core/deref'), s:read_bang(port))
  elseif empty(token)
    return g:timl#reader#eof
  elseif token ==# a:wanted
    return s:found
  else
    let error = 'timl#reader: unexpected token '.string(token)
  endif
  throw error . ' on line ' . line
endfunction

function! s:read_bang(port) abort
  let val = s:read(a:port)
  if val isnot# g:timl#reader#eof
    return val
  endif
  throw 'timl#reader: unexpected EOF'
endfunction

let s:quote = timl#symbol('quote')
let s:unquote = timl#symbol('unquote')
let s:unquote_splicing = timl#symbol('unquote-splicing')
let s:list = timl#symbol('timl.core/list')
let s:concat = timl#symbol('timl.core/concat')
let s:seq = timl#symbol('timl.core/seq')
let s:vec = timl#symbol('timl.core/vec')
let s:set = timl#symbol('timl.core/set')
let s:hash_map = timl#symbol('timl.core/hash-map')
function! timl#reader#syntax_quote(form, gensyms) abort
  if timl#symbol#test(a:form)
    if a:form[0] =~# '^[^/]\+#$'
      if !has_key(a:gensyms, a:form[0])
        let a:gensyms[a:form[0]] = timl#symbol(timl#gensym(a:form[0][0:-2].'__')[0].'__auto__')
      endif
      let quote = s:quote
      let x = timl#list(s:quote, a:gensyms[a:form[0]])
      return timl#list(s:quote, a:gensyms[a:form[0]])
    elseif a:form[0] !~# '/.'
      return timl#list(s:quote, timl#symbol(timl#compiler#qualify(a:form[0], g:timl#core#_STAR_ns_STAR_.name, a:form[0])))
    else
      return timl#list(s:quote, a:form)
    endif
  elseif timl#vectorp(a:form)
    return timl#list(s:vec, timl#cons(s:concat, s:sqexpandlist(a:form, a:gensyms)))
  elseif timl#setp(a:form)
    return timl#list(s:set, timl#cons(s:concat, s:sqexpandlist(a:form, a:gensyms)))
  elseif timl#mapp(a:form)
    let _ = {'seq': timl#seq(a:form)}
    let keyvals = []
    while _.seq isnot# g:timl#nil
      call extend(keyvals, timl#ary(timl#first(_.seq)))
      let _.seq = timl#next(_.seq)
    endwhile
    return timl#list(s:hash_map, timl#cons(s:concat, s:sqexpandlist(keyvals, a:gensyms)))

  elseif timl#collp(a:form)
    let first = timl#first(a:form)
    if first is# s:unquote
      return timl#first(timl#rest(a:form))
    elseif first is# s:unquote_splicing
      throw 'timl#reader: unquote-splicing used outside of list'
    else
      return timl#list(s:seq, timl#cons(s:concat, s:sqexpandlist(a:form, a:gensyms)))
    endif
  else
    return a:form
  endif
endfunction

function! s:sqexpandlist(seq, gensyms) abort
  let result = []
  let _ = {'seq': timl#seq(a:seq)}
  while _.seq isnot# g:timl#nil
    let _.this = timl#first(_.seq)
    if timl#consp(_.this)
      if timl#first(_.this) is# s:unquote
        call add(result, timl#list(s:list, timl#first(timl#rest(_.this))))
      elseif timl#first(_.this) is# s:unquote_splicing
        call add(result, timl#first(timl#rest(_.this)))
      else
        call add(result, timl#list(s:list, timl#reader#syntax_quote(_.this, a:gensyms)))
      endif
    else
      call add(result, timl#list(s:list, timl#reader#syntax_quote(_.this, a:gensyms)))
    endif
    let _.seq = timl#next(_.seq)
  endwhile
  return result
endfunction

function! timl#reader#open(filename) abort
  let str = join(readfile(a:filename), "\n")
  return {'str': str, 'filename': a:filename, 'pos': 0, 'line': 1}
endfunction

function! timl#reader#close(port)
  return a:port
endfunction

function! timl#reader#read_all(port) abort
  let all = []
  let _ = {}
  try
    while 1
      let _.form = s:read(a:port)
      if _.form is# g:timl#reader#eof
        return all
      endif
      call add(all, _.form)
    endwhile
  catch /^timl.*/
    let error = v:exception
  endtry
  throw error
endfunction

function! timl#reader#read_string_all(str) abort
  return timl#reader#read_all({'str': a:str, 'pos': 0, 'line': 1})
endfunction

function! timl#reader#read_string(str) abort
  return timl#reader#read({'str': a:str, 'pos': 0, 'line': 1})
endfunction

function! timl#reader#read_file(filename) abort
  return timl#reader#read_string_all(join(readfile(a:filename), "\n"))
endfunction

" Section: Tests {{{1

if !$TIML_TEST
  finish
endif

command! -nargs=1 TimLRAssert
      \ try |
      \ if !eval(<q-args>) |
      \ echomsg "Failed: ".<q-args> |
      \   endif |
      \ catch /.*/ |
      \  echomsg "Error:  ".<q-args>." (".v:exception.")" |
      \ endtry

TimLRAssert timl#reader#read_string('foo') ==# timl#symbol('foo')
TimLRAssert timl#reader#read_string('":)"') ==# ':)'
TimLRAssert timl#reader#read_string('#"\(a\\\)"') ==# '\(a\\\)'
TimLRAssert timl#reader#read_string('#"\""') ==# '"'
TimLRAssert timl#reader#read_string('(first [1 2])') ==# timl#list(timl#symbol('first'), timl#vector(1, 2))
TimLRAssert timl#reader#read_string('#["a" 1 "b" 2]') ==# {"a": 1, "b": 2}
TimLRAssert timl#reader#read_string('{"a" 1 :b 2 3 "c"}') ==# timl#hash_map("a", 1, timl#keyword#intern('b'), 2, 3, "c")
TimLRAssert timl#reader#read_string("[1]\n; hi\n") ==# timl#vector(1)
TimLRAssert timl#reader#read_string("'[1 2 3]") ==# timl#list(timl#symbol('quote'), timl#vector(1, 2, 3))
TimLRAssert timl#reader#read_string("#*tr") ==# timl#list(timl#symbol('function'), timl#symbol('tr'))
TimLRAssert timl#reader#read_string("(1 #_2 3)") ==# timl#list(1, 3)
TimLRAssert timl#reader#read_string("^:foo {}") ==#
      \ timl#with_meta(timl#hash_map(), timl#hash_map(timl#keyword#intern('foo'), g:timl#true))

TimLRAssert timl#reader#read_string("~foo") ==# timl#list(s:unquote, timl#symbol('foo'))
TimLRAssert timl#first(timl#rest(timl#reader#read_string("`foo#")))[0] =~# '^foo__\d\+__auto__'

delcommand TimLRAssert

" }}}1

" vim:set et sw=2:
