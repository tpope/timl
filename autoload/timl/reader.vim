" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:autoloaded_timl_reader")
  finish
endif
let g:autoloaded_timl_reader = 1

let s:iskeyword = '[[:alnum:]_=?!#$%&*+|./<>:-]'

function! s:read_token(port) abort
  let pat = '^\%(#"\%(\\\@<!\%(\\\\\)*\\"\|[^"]\)*"\|"\%(\\.\|[^"]\)*"\|[[:space:],]\+\|\%(;\|#!\)[^'."\n".']*\|\~@\|#[[:punct:]]\|'.s:iskeyword.'\+\|\\\%(space\|tab\|newline\|return\|.\)\|.\)'
  let match = ' '
  while match =~# '^[[:space:],]'
    let [pos, line] = [a:port.pos, a:port.line]
    let match = matchstr(a:port.str, pat, a:port.pos)
    let a:port.pos += len(match)
    let a:port.line += len(substitute(match, "[^\n]", '', 'g'))
  endwhile
  return [match, pos, line]
endfunction

function! timl#reader#eofp(port) abort
  return a:port.pos >= len(a:port.str)
endfunction

let g:timl#reader#eof = []

function! timl#reader#read(port, ...) abort
  let error = 'timl#reader: unexpected EOF'
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
function! s:read_until(port, char) abort
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
  throw 'timl#reader: unexpected EOF'
endfunction

let s:constants = {
      \ '\space': " ",
      \ '\tab': "\t",
      \ '\newline': "\n",
      \ '\return': "\r",
      \ '\formfeed': "\f",
      \ '\backspace': "\b"}

function! s:add_meta(data, meta) abort
  let _ = {}
  let _.meta = timl#meta#get(a:data)
  if _.meta is g:timl#nil
    let _.meta = a:meta
  else
    let _.meta = timl#coll#into(_.meta, a:meta)
  endif
  return timl#meta#with(a:data, _.meta)
endfunction

let s:map_type = timl#type#core_create('HashMap')
function! s:read(port, ...) abort
  let port = a:port
  let [token, pos, line] = s:read_token(a:port)
  let wanted = a:0 ? a:1 : ''
  if token ==# '('
    let meta = timl#type#bless(s:map_type, {'line': line, '__length': 1, '__root': {}})
    return timl#list#create(s:read_until(port, ')'), meta)
  elseif token == '['
    return timl#vector#claim(s:read_until(port, ']'))
  elseif token == '{'
    let list = s:read_until(port, '}')
    if len(list) % 2 != 0
      let error = 'timl#reader: invalid hash map literal'
    else
      return timl#map#create(list)
    endif
  elseif token == '#{'
    return timl#set#coerce(s:read_until(port, '}'))
  elseif has_key(s:constants, token)
    return s:constants[token]
  elseif token ==# 'nil'
    return g:timl#nil
  elseif token ==# 'false'
    return g:timl#false
  elseif token ==# 'true'
    return g:timl#true
  elseif token ==# 'Infinity' || token ==# '+Infinity'
    return 1/(0.0)
  elseif token ==# '-Infinity'
    return -1/(0.0)
  elseif token ==# 'NaN'
    return 0/(0.0)
  elseif token =~# '^\d\+e\d\+$'
    return eval(substitute(token, 'e', '.0e', ''))
  elseif token =~# '^\.\d'
    return eval('0'.token)
  elseif token =~# '^"\|^[+-]\=\d\%(.*\d\)\=$'
    return eval(token)
  elseif token =~# '^#"'
    return '\C\v'.substitute(token[2:-2], '\\\@<!\(\%(\\\\\)*\)\\"', '\1"', 'g')
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
  elseif token ==# "#'"
    return timl#list(timl#symbol('var'), s:read_bang(port))
  elseif token ==# '#*'
    let next = s:read_bang(port)
    if timl#map#test(next)
      return timl#dictionary#create([next])
    elseif timl#vector#test(next)
      return timl#array#coerce(next)
    else
      return timl#list(timl#symbol('function'), next)
    endif
  elseif token[0] ==# ';' || token =~# '^#!'
    return s:read(port, wanted)
  elseif token ==# '#_'
    call s:read(port)
    return s:read(port, wanted)
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
      return timl#list(timl#symbol('fn*'), args, timl#list#create(list))
    finally
      unlet! a:port.argsyms
    endtry
  elseif token =~# '^%\d*$\|^%&$' && has_key(port, 'argsyms')
    let token = (token ==# '%' ? '%1' : token)
    if !has_key(port.argsyms, token)
      let port.argsyms[token] = timl#symbol#gen('p1__')
    endif
    return port.argsyms[token]

  elseif token ==# '#uuid'
    return tolower(s:read(port))

  elseif token ==# '#inst'
    return timl#inst#parse(s:read(port))

  elseif token =~# '^#\a'
    let next = s:read(port)
    unlockvar 1 next
    let token = token[1:-1]
    if token !~# '[/.]'
      let token = 'timl.lang/'.token
    endif
    let munged = timl#var#munge(token)
    if timl#map#test(next) && exists("g:".substitute(munged, '.*\zs#', '#map__GT_', ''))
      return timl#invoke(g:{substitute(munged, '.*\zs#', '#map__GT_', '')}, next)
    elseif timl#vector#test(next) && exists("g:".substitute(munged, '.*\zs#', '#__GT_', ''))
      return timl#call(g:{substitute(munged, '.*\zs#', '#__GT_', '')}, timl#array#coerce(next))
    else
      throw 'timl#reader: invalid tag ' . token . ' on ' . timl#type#string(next)
    endif
  elseif token =~# '^::.\+/.'
    let alias = matchstr(token[2:-1], '.*\ze/.')
    let ns = get(timl#namespace#aliases(g:timl#core._STAR_ns_STAR_), alias, {})
    if empty(ns)
      let error = 'timl#reader: unknown ns alias '.alias.' in keyword'
    else
      return timl#keyword#intern(timl#namespace#the(ns).name[0].matchstr(token, '.*\zs/.\+'))
    endif
  elseif token =~# '^::.'
    return timl#keyword#intern(timl#namespace#name(g:timl#core._STAR_ns_STAR_).str.'/'.token[2:-1])
  elseif token =~# '^:.'
    return timl#keyword#intern(token[1:-1])
  elseif token =~# '^'.s:iskeyword
    return timl#symbol(token)
  elseif token ==# '^'
    let _meta = s:read(port)
    let data = s:read(port)
    if timl#keyword#test(_meta)
      let meta = timl#map#create([_meta, g:timl#true])
    elseif timl#symbol#test(_meta) || type(_meta) == type('')
      let meta = timl#map#create([timl#keyword#intern('tag'), _meta])
    elseif timl#map#test(_meta)
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
  elseif token ==# wanted
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
let s:function = timl#symbol('function')
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
        let a:gensyms[a:form[0]] = timl#symbol(timl#symbol#gen(a:form[0][0:-2].'__')[0].'__auto__')
      endif
      let quote = s:quote
      let x = timl#list(s:quote, a:gensyms[a:form[0]])
      return timl#list(s:quote, a:gensyms[a:form[0]])
    elseif !timl#compiler#specialp(a:form[0]) && a:form[0] !~# ':\|^[&$]'
      return timl#list(s:quote, timl#symbol(timl#namespace#maybe_resolve(
            \ g:timl#core._STAR_ns_STAR_,
            \ a:form,
            \ {'str': (a:form[0] =~# '/.' ? '' : timl#namespace#name(g:timl#core._STAR_ns_STAR_).str.'/').a:form[0]}).str))
    else
      return timl#list(s:quote, a:form)
    endif
  elseif timl#vector#test(a:form)
    return timl#list(s:vec, timl#cons#create(s:concat, s:sqexpandlist(a:form, a:gensyms)))
  elseif timl#set#test(a:form)
    return timl#list(s:set, timl#cons#create(s:concat, s:sqexpandlist(a:form, a:gensyms)))
  elseif timl#map#test(a:form)
    let _ = {'seq': timl#coll#seq(a:form)}
    let keyvals = []
    while _.seq isnot# g:timl#nil
      call extend(keyvals, timl#array#coerce(timl#coll#first(_.seq)))
      let _.seq = timl#coll#next(_.seq)
    endwhile
    return timl#list(s:hash_map, timl#cons#create(s:concat, s:sqexpandlist(keyvals, a:gensyms)))

  elseif timl#coll#test(a:form)
    let first = timl#coll#first(a:form)
    if first is# s:unquote
      return timl#coll#first(timl#coll#rest(a:form))
    elseif first is# s:unquote_splicing
      throw 'timl#reader: unquote-splicing used outside of list'
    elseif first is# s:function
      return a:form
    else
      return timl#list(s:seq, timl#cons#create(s:concat, s:sqexpandlist(a:form, a:gensyms)))
    endif
  else
    return a:form
  endif
endfunction

function! s:sqexpandlist(seq, gensyms) abort
  let result = []
  let _ = {'seq': timl#coll#seq(a:seq)}
  while _.seq isnot# g:timl#nil
    let _.this = timl#coll#first(_.seq)
    if timl#coll#seqp(_.this)
      if timl#coll#first(_.this) is# s:unquote
        call add(result, timl#list(s:list, timl#coll#first(timl#coll#rest(_.this))))
      elseif timl#coll#first(_.this) is# s:unquote_splicing
        call add(result, timl#coll#first(timl#coll#rest(_.this)))
      else
        call add(result, timl#list(s:list, timl#reader#syntax_quote(_.this, a:gensyms)))
      endif
    else
      call add(result, timl#list(s:list, timl#reader#syntax_quote(_.this, a:gensyms)))
    endif
    let _.seq = timl#coll#next(_.seq)
  endwhile
  return result
endfunction

function! timl#reader#open(filename) abort
  let str = join(readfile(a:filename), "\n")
  return {'str': str, 'filename': fnamemodify(a:filename, ':p'), 'pos': 0, 'line': 1}
endfunction

function! timl#reader#open_string(string, ...) abort
  let port = {'str': a:string, 'pos': 0, 'line': a:0 > 1 ? a:2 : 1}
  if a:0
    let port.filename = a:1
  endif
  return port
endfunction

function! timl#reader#close(port) abort
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

TimLRAssert timl#equality#test(timl#reader#read_string('foo'), timl#symbol('foo'))
TimLRAssert timl#equality#test(timl#reader#read_string('":)"'), ':)')
TimLRAssert timl#equality#test(timl#reader#read_string('#"\(a\\\)"'), '\C\v\(a\\\)')
TimLRAssert timl#equality#test(timl#reader#read_string('#"\""'), '\C\v"')
TimLRAssert timl#equality#test(timl#reader#read_string('(first [1 2])'), timl#list(timl#symbol('first'), timl#vector#claim([1, 2])))
TimLRAssert timl#equality#test(timl#reader#read_string('#*{"a" 1 "b" 2}'), {"a": 1, "b": 2})
TimLRAssert timl#equality#test(timl#reader#read_string('{"a" 1 :b 2 3 "c"}'), timl#map#create(["a", 1, timl#keyword#intern('b'), 2, 3, "c"]))
TimLRAssert timl#equality#test(timl#reader#read_string("[1]\n; hi\n"), timl#vector#claim([1]))
TimLRAssert timl#equality#test(timl#reader#read_string("'[1 2 3]"), timl#list(timl#symbol('quote'), timl#vector#claim([1, 2, 3])))
TimLRAssert timl#equality#test(timl#reader#read_string("#*tr"), timl#list(timl#symbol('function'), timl#symbol('tr')))
TimLRAssert timl#equality#test(timl#reader#read_string("(1 #_2 3)"), timl#list(1, 3))
TimLRAssert timl#equality#test(timl#reader#read_string("^:foo ()"),
      \ timl#meta#with(g:timl#empty_list, timl#map#create([timl#keyword#intern('foo'), g:timl#true])))

TimLRAssert timl#equality#test(timl#reader#read_string("~foo"), timl#list(s:unquote, timl#symbol('foo')))
TimLRAssert timl#coll#first(timl#coll#rest(timl#reader#read_string("`foo#")))[0] =~# '^foo__\d\+__auto__'

delcommand TimLRAssert

" }}}1

" vim:set et sw=2:
