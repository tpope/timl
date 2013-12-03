" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_compiler')
  finish
endif
let g:autoloaded_timl_compiler = 1

let s:escapes = {
      \ "\b": '\b',
      \ "\e": '\e',
      \ "\f": '\f',
      \ "\n": '\n',
      \ "\r": '\r',
      \ "\t": '\t',
      \ "\"": '\"',
      \ "\\": '\\'}

function! timl#compiler#serialize(x)
  " TODO: guard against recursion
  if timl#symbolp(a:x)
    return 'timl#symbol('.timl#compiler#serialize(a:x[0]).')'

  elseif a:x is# g:timl#nil
    return 'g:timl#nil'

  elseif type(a:x) == type([])
    return '['.join(map(copy(a:x), 'timl#compiler#serialize(v:val)'), ', ').']'

  elseif type(a:x) == type({})
    let acc = []
    for [k, V] in items(a:x)
      call add(acc, timl#compiler#serialize(k) . ': ' . timl#compiler#serialize(V))
      unlet! V
    endfor
    return '{' . join(acc, ', ') . '}'

  elseif type(a:x) == type('')
    return '"'.substitute(a:x, "[\001-\037\"\\\\]", '\=get(s:escapes, submatch(0), printf("\\%03o", char2nr(submatch(0))))', 'g').'"'
  else
    return string(a:x)
  endif
endfunction

function! s:gensym(...)
  let s:id = get(s:, 'id', 0) + 1
  return (a:0 ? a:1 : 'G__').s:id
endfunction

function! s:tempsym(...)
  return 'temp.'.s:gensym(a:0 ? a:1 : 'emit')
endfunction

function! s:println(file, line)
  if a:line ==# 'g:timl#nil'
    throw "WHAT THE FUCK"
  endif
  call extend(a:file, split(a:line, "\n"))
  return a:line . "\n"
endfunction

function! s:printfln(file, ...)
  let line = call('printf', a:000)
  return s:println(a:file, line)
endfunction

function! timl#compiler#build(x, ns, ...) abort
  let file = []
  call s:emit(file, a:0 ? a:1 : "return %s", a:ns, {}, a:x)
  return join(file, "\n") . "\n"
endfunction

function! timl#compiler#eval(x, ...) abort
  let _ns = a:0 ? timl#str(a:1) : 'user'
  let locals = [{}]
  let temp = {}
  let _dict = {}
  let _str = "function _dict.func(locals) abort\n"
        \ . "let locals=[a:locals]\n"
        \ . "let temp={}\n"
        \ . "while 1\n"
        \ . timl#compiler#build(a:x, _ns, "return %s")
        \ . "endwhile\n"
        \ . "endfunction"
  execute _str
  return _dict.func(a:0 > 1 ? a:2 : {})
endfunction

function! s:emit(file, context, ns, locals, x) abort
  let _ = {}
  let x = a:x
  if timl#symbolp(x)
    if has_key(a:locals, x[0])
      return s:printfln(a:file, a:context, "locals[0][".string(x[0])."]")
    else
      return s:printfln(a:file, a:context, "timl#lookup(".timl#compiler#serialize(x).", ".string(a:ns).", locals[0])")
    endif

  elseif x is# g:timl#nil
    return s:printfln(a:file, a:context, 'g:timl#nil')

  elseif type(x) == type([])
    let sym = s:tempsym('vec')
    call s:println(a:file, 'let '.sym." = []")
    for _.e in x
      call s:emit(a:file, "call add(".sym.", %s)", a:ns, a:locals, _.e)
    endfor
    return s:printfln(a:file, a:context, sym)

  elseif type(x) == type({}) && !timl#consp(x)
    let sym = s:tempsym('dict')
    call s:println(a:file, 'let '.sym." = {}")
    for [k, _.v] in items(x)
      if timl#symbolp(get(x, '#tag')) && x['#tag'][0] =~# '^#'
        if k =~# '^#'
          call s:emit(a:file, "let ".sym."[".timl#compiler#serialize(k)."] = %s", a:ns, a:locals, _.v)
        else
          let _.k = timl#dekey(k)
          call s:emit(a:file, "let ".sym."_key = %s", a:ns, a:locals, _.k)
          call s:emit(a:file, "let ".sym."[timl#key(".sym."_key)] = %s", a:ns, a:locals, _.v)
        endif
      else
        call s:emit(a:file, "let ".sym."[".timl#compiler#serialize(k)."] = %s", a:ns, a:locals, _.v)
      endif
    endfor
    return s:printfln(a:file, a:context, sym)

  elseif !timl#consp(x)
    return s:printfln(a:file, a:context, timl#compiler#serialize(x))

  endif

  let F = timl#car(x)
  let rest = timl#cdr(x)
  let vec = timl#vec(rest)

  if F is timl#symbol(':')
    return call('timl#compiler#emit__COLON_', [a:file, a:context, a:ns, a:locals] + vec)
  elseif timl#symbolp(F) && exists('*timl#compiler#emit_'.timl#munge(F))
    return call("timl#compiler#emit_".timl#munge(F), [a:file, a:context, a:ns, a:locals] + vec)
  endif

  let tmp = s:tempsym('invoke')
  if timl#symbolp(F) && !has_key(a:locals, F[0])
    let Fn = timl#lookup(F, a:ns, {})
    let name = join([Fn])
    if type(Fn) == type(function('tr')) && get(get(g:timl#lambdas, name, {}), 'macro')
      return s:emit(a:file, a:context, a:ns, a:locals, timl#call(Fn, vec))
    elseif type(Fn) == type(function('tr'))
      call s:emit(a:file, "let ".tmp."_args = %s", a:ns, a:locals, vec)
      return s:printfln(a:file, a:context, "timl#call(".string(name).', '.tmp."_args)")
    endif
    call s:emit(a:file, "let ".tmp."_args = %s", a:ns, a:locals, vec)
    let lookup = "timl#lookup(".string(F).", ".string(a:ns).", locals[0])"
    return s:printfln(a:file, a:context, "timl#call(".lookup.", ".tmp."_args)")
  else
    call s:emit(a:file, "let ".tmp."_args = %s", a:ns, a:locals, vec)
    call s:emit(a:file, "let ".tmp."_function = %s", a:ns, a:locals, F)
    return s:printfln(a:file, a:context, "timl#call(".tmp."_function, ".tmp."_args)")
  endif
endfunction

function! timl#compiler#emit_set_BANG_(file, context, ns, locals, var, value) abort
  if timl#symbolp(a:var)
    let var = a:var[0]
    if var =~# '^\w:\|^&'
      let var = var[0].timl#munge(var[1:-1])
    else
      let var = 'g:'.timl#munge(var)
    endif
    call s:emit(a:file, 'let '.var.' =  %s', a:ns, a:locals, a:value)
    return s:printfln(a:file, a:context, 'g:timl#nil')
  elseif timl#consp(a:var)
    let vec = timl#vec(a:var)
    if len(vec) == 3 && vec[0] is timl#symbol('.')
      let tmp = s:tempsym('setq')
      call s:emit(a:file, 'let '.tmp.'_coll =  %s', a:ns, a:locals, vec[1])
      call s:emit(a:file, 'let '.tmp.'_coll['.timl#compiler#serialize(timl#str(vec[2])).'] =  %s', a:ns, a:locals, a:value)
      return s:printfln(a:file, a:context, 'g:timl#nil')
    endif
  endif
  throw 'timl: invalid set! form'
endfunction

function! timl#compiler#emit_function(file, context, ns, locals, name) abort
  return s:printfln(a:file, a:context, 'function('.string(a:name[0]).')')
endfunction

function! timl#compiler#emit_if(file, context, ns, locals, cond, then, ...) abort
  return s:emit(a:file, "if timl#truth(%s)", a:ns, a:locals, a:cond)
        \ . s:emit(a:file, a:context, a:ns, a:locals, a:then)
        \ . s:println(a:file, "else")
        \ . s:emit(a:file, a:context, a:ns, a:locals, a:0 ? a:1 : g:timl#nil)
        \ . s:println(a:file, "endif")
endfunction

function! timl#compiler#emit_recur(file, context, ns, locals, ...) abort
  if a:context ==# "return %s"
    let sym = s:tempsym('recur')
    call s:println(a:file, "let newlocals = [copy(locals[0])]")
    call s:emit(a:file, "call extend(newlocals[0], timl#l2env(my_impl, %s))", a:ns, a:locals, a:000)
    call s:println(a:file, "let locals = newlocals")
    return s:println(a:file, "continue")
  endif
  throw 'timl#compiler: recur called outside tail position'
endfunction

function! timl#compiler#emit_fn_STAR_(file, context, ns, locals, params, ...) abort
  let sym = s:tempsym('fn')
  call s:println(a:file, "let ".sym."_impl = {'env': locals[0], 'ns': ".string(a:ns)."}")
  if timl#symbolp(a:params)
    call s:println(a:file, "let ".sym."_impl.name = ".string(a:params[0]))
    let params = timl#vec(get(a:000, 0, []))
    let body = a:000[1:-1]
  else
    let params = timl#vec(a:params)
    let body = a:000
  endif
  call s:println(a:file, "let ".sym."_impl.arglist = ".timl#compiler#serialize(params))
  let sig = join(map(copy(params), "v:val is# timl#symbol('...') ? '...' : timl#munge(v:val)"), ", ")
  call s:println(a:file, "function! ".sym."_func(".sig.") abort")
  call s:println(a:file, "let my_name = matchstr(expand('<sfile>'), '.*\\%(\\.\\.\\| \\)\\zs.*')")
  call s:println(a:file, "let my_impl = g:timl#lambdas[my_name]")
  call s:println(a:file, "let temp = {}")
  call s:println(a:file, "let locals = [extend(timl#a2env(my_impl, a:), copy(my_impl.env), 'keep')]")
  call s:println(a:file, "if !empty(get(my_impl, 'name', ''))")
  call s:println(a:file, "let locals[0][timl#symbol(my_impl.name)[0]] = my_name =~ '^\\d' ? self.__fn__ : function(my_name)")
  call s:println(a:file, "endif")
  call s:println(a:file, "while 1")
  let locals = copy(a:locals)
  let _ = {}
  for _.param in params
    let locals[timl#str(_.param)] = 1
  endfor
  if timl#symbolp(a:params)
    let locals[a:params[0]] = 1
  endif
  call call('timl#compiler#emit_do', [a:file, "return %s", a:ns, locals] + body)
  call s:println(a:file, "endwhile")
  call s:println(a:file, "endfunction")
  call s:println(a:file, "let g:timl#lambdas[join([".sym."_func])] = ".sym."_impl")
  return s:printfln(a:file, a:context, sym."_func")
endfunction

function! timl#compiler#emit_let_STAR_(file, context, ns, locals, bindings, ...) abort
  let _ = {}
  let locals = copy(a:locals)
  let tmp = s:tempsym('let')
  call s:println(a:file, "let ".tmp." = copy(locals[0])")
  call s:println(a:file, "call insert(locals, ".tmp.")")
  if type(a:bindings) == type([])
    if len(a:bindings) % 2 !=# 0
      throw "timl(let): even number of forms required" . len(a:bindings)
    endif
    for i in range(0, len(a:bindings)-1, 2)
      call s:emit(a:file,
            \ "let ".tmp."[".string(timl#str(a:bindings[i]))."] = %s",
            \ a:ns, locals, a:bindings[i+1])
      let locals[timl#str(a:bindings[i])] = 1
    endfor
  else
    let list = timl#vec(a:bindings)
    for binding in timl#vec(a:bindings)
      let [_.var, _.val] = timl#vec(binding)
      call s:emit(a:file, "let ".tmp."[".string(timl#str(_.var))."] = %s", a:ns, locals, _.val)
      let locals[timl#str(_.var)] = 1
    endfor
  endif
  call call('timl#compiler#emit_do', [a:file, a:context, a:ns, a:locals] + a:000)
  return s:println(a:file, "call remove(locals, 0)")
endfunction

function! timl#compiler#emit_do(file, context, ns, locals, ...) abort
  let _ = {}
  let sym = s:tempsym('trash')
  for _.x in a:000[0:-2]
    call s:emit(a:file, "let ".sym." = %s", a:ns, a:locals, _.x)
  endfor
  return s:emit(a:file, a:context, a:ns, a:locals, get(a:000, -1, g:timl#nil))
  return str
endfunction

function! timl#compiler#emit_def(file, context, ns, locals, sym, ...) abort
  if a:0
    let Val = a:1
  else
    return s:printfln(a:file, a:context, "timl#define_global(timl#munge(g:timl#core#_STAR_ns_STAR_[0].".string('#'.timl#str(a:sym))."))")
  endif
  let tmp = s:tempsym('def')
  if timl#consp(a:sym)
    let sym = timl#car(a:sym)
    call timl#compiler#emit_fn_STAR_(a:file, 'let '.tmp.' = %s', a:ns, a:locals, sym, timl#cdr(a:sym), Val)
  else
    let sym = a:sym
    call s:emit(a:file, 'let '.tmp." = %s", a:ns, a:locals, Val)
  endif
  return s:printfln(a:file, a:context, "timl#define_global(timl#munge(g:timl#core#_STAR_ns_STAR_[0].".string('#'.sym[0]).") ,".tmp.")")
endfunction

function! timl#compiler#emit__COLON_(file, context, ns, locals, ...) abort
  let tmp = s:tempsym('execute')
  call s:emit(a:file, 'let '.tmp." = %s", a:ns, a:locals, a:000)
  call s:println(a:file, "execute join(".tmp.", ' ')")
  return s:printfln(a:file, a:context, "g:timl#nil")
endfunction

function! timl#compiler#emit_quote(file, context, ns, locals, form) abort
  return s:printfln(a:file, a:context, timl#compiler#serialize(a:form))
endfunction

let s:unquote          = timl#symbol('unquote')
let s:unquote_splicing = timl#symbol('unquote-splicing')
function! timl#compiler#emit_syntax_quote(file, context, ns, locals, form, ...) abort
  let gensyms = a:0 ? a:1 : {}
  let _ = {}
  if timl#consp(a:form)
    if timl#car(a:form) is s:unquote
      return s:emit(a:file, a:context, a:ns, a:locals, timl#car(timl#cdr(a:form)))
    endif
    let tmp = s:tempsym('quasiquote')
    call s:println(a:file, 'let '.tmp.' = []')
    let form = timl#vec(a:form)
    for _.v in form
      if timl#consp(_.v) && timl#car(_.v) is# s:unquote_splicing
        call s:emit(a:file, 'call extend('.tmp.', %s)', a:ns, a:locals, timl#car(timl#cdr(_.v)))
      else
        call timl#compiler#emit_syntax_quote(a:file, 'call add('.tmp.', %s)', a:ns, a:locals, _.v, gensyms)
      endif
    endfor
    return s:printfln(a:file, a:context, 'timl#list2('.tmp.')')
  elseif timl#symbolp(a:form)
    if a:form[0] =~# '#$'
      if !has_key(gensyms, a:form[0])
        let gensyms[a:form[0]] = timl#symbol(s:gensym(a:form[0][0:-2]))
      endif
      let sym = gensyms[a:form[0]]
    else
      let sym = a:form
    endif
    return s:printfln(a:file, a:context, timl#compiler#serialize(timl#qualify([a:locals, a:ns], sym)))
  elseif type(a:form) == type([])
    let tmp = s:tempsym('quasiquote')
    call s:println(a:file, 'let '.tmp.' = []')
    for _.v in a:form
      call timl#compiler#emit_syntax_quote(a:file, 'call add('.tmp.', %s)', a:ns, a:locals, _.v, gensyms)
    endfor
    return s:printfln(a:file, a:context, tmp)
  elseif type(a:form) == type([])
    let tmp = s:tempsym('quasiquote')
    call s:println(a:file, 'let '.tmp.' = {}')
    for [k, _.v] in items(a:form)
      call timl#compiler#emit_syntax_quote(a:file, 'let '.tmp.'['.timl#compiler#serialize(k).'] = %s', a:ns, a:locals, _.v, gensyms)
    endfor
    return s:printfln(a:file, a:context, tmp)
  else
    return s:emit(a:file, a:context, a:ns, a:locals, a:form)
  endif
endfunction

let s:catch   = timl#symbol('catch')
let s:finally = timl#symbol('finally')
function! timl#compiler#emit_try(file, context, ns, locals, ...) abort
  let _ = {}
  let tmp = s:tempsym('try')
  call s:println(a:file, 'try')
  for i in range(a:0)
    let _.e = a:000[i]
    if timl#car(_.e) is s:catch || timl#car(_.e) is s:finally
      break
    endif
    call s:emit(a:file, 'let '.tmp.' = %s', a:ns, a:locals, _.e)
  endfor
  call s:printfln(a:file, a:context, tmp)
  for i in range(i, a:0-1)
    let _.e = a:000[i]
    if timl#car(_.e) is s:finally
      call s:println(a:file, 'finally')
      call call('timl#compiler#emit_do', [a:file, 'let '.tmp.' = %s', a:ns, a:locals] + timl#vec(timl#cdr(_.e)))
    elseif timl#car(_.e) is s:catch
      let rest = timl#vec(timl#cdr(_.e))
      let _.pattern = rest[0]
      if type(_.pattern) == type(0)
        let _.pattern = '^Vim\%((\a\+)\)\=:E' . _.pattern
      endif
      let var = rest[1]
      call s:println(a:file, 'catch /'._.pattern.'/')
      call s:println(a:file, "call insert(locals, copy(locals[0]))")
      call s:println(a:file, "let locals[0][".string(var[0])."] = timl#build_exception(v:exception, v:throwpoint)")
      call call('timl#compiler#emit_do', [a:file, a:context, a:ns, a:locals] + rest[2:-1])
      call s:println(a:file, "call remove(locals, 0)")
    endif
  endfor
  return s:println(a:file, 'endtry')
endfunction
