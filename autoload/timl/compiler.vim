" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_compiler')
  finish
endif
let g:autoloaded_timl_compiler = 1

" Section: Symbol resolution {{{1

let s:specials = {
      \ 'if': 1,
      \ 'do': 1,
      \ 'let*': 1,
      \ 'fn*': 1,
      \ 'def': 1,
      \ ':': 1,
      \ '.': 1,
      \ 'quote': 1,
      \ 'function': 1,
      \ 'throw': 1,
      \ 'try': 1,
      \ 'catch': 1,
      \ 'finally': 1}

function! timl#compiler#specialp(sym)
  return has_key(s:specials, timl#str(a:sym))
endfunction

function! timl#compiler#qualify(sym, ns, ...)
  let sym = type(a:sym) == type('') ? a:sym : a:sym[0]
  let the_ns = timl#the_ns(a:ns)
  if timl#compiler#specialp(sym)
    return sym
  elseif sym =~# '^\w:\|^\$'
    return sym
  elseif sym =~# '^&\w' && exists(sym)
    return sym
  elseif sym =~# '/.' && has_key(the_ns.aliases, matchstr(sym, '.\{-\}\ze/.'))
    let sym = the_ns.aliases[matchstr(sym, '.\{-\}\ze/.')][0] . '/' . matchstr(sym, '.\{-\}/\zs.\+')
  endif
  if sym =~# '/.' && exists('g:'.timl#munge(sym))
    return sym
  endif
  for ns in [the_ns.name] + the_ns.referring
    let target = timl#str(ns).'/'.sym
    if exists('g:'.timl#munge(target))
      return target
    endif
  endfor
  if a:0
    return a:1
  endif
  throw 'timl#compiler: could not resolve '.timl#str(a:sym)
endfunction

function! timl#compiler#resolve(sym, ns)
  let sym = timl#compiler#qualify(a:sym, a:ns)
  if sym =~# '^[&$]'
    return sym
  elseif sym =~# '^\w:'
    return timl#munge(sym)
  else
    return timl#munge('g:'.sym)
  endif
endfunction

function! timl#compiler#lookup(sym, ns) abort
  return eval(timl#compiler#resolve(a:sym, a:ns))
endfunction

" }}}1
" Section: Emission {{{1

let s:escapes = {
      \ "\b": '\b',
      \ "\e": '\e',
      \ "\f": '\f',
      \ "\n": '\n',
      \ "\r": '\r',
      \ "\t": '\t',
      \ "\"": '\"',
      \ "\\": '\\'}

function! timl#compiler#serialize(x, ...)
  if !a:0
    let meta = timl#meta(a:x)
    if !empty(meta)
      return 'timl#with_meta('.timl#compiler#serialize(a:x, 'nometa').', '.timl#compiler#serialize(meta).')'
    endif
  endif
  " TODO: guard against recursion
  if timl#keywordp(a:x)
    return 'timl#keyword('.timl#compiler#serialize(a:x[0]).')'

  elseif timl#symbolp(a:x)
    return 'timl#symbol('.timl#compiler#serialize(a:x[0]).')'

  elseif a:x is# g:timl#nil
    return 'g:timl#nil'

  elseif a:x is# g:timl#false
    return 'g:timl#false'

  elseif a:x is# g:timl#true
    return 'g:timl#true'

  elseif a:x is# g:timl#empty_list
    return 'g:timl#empty_list'

  elseif type(a:x) == type([])
    return '['.join(map(copy(a:x), 'timl#compiler#serialize(v:val)'), ', ').']'

  elseif timl#mapp(a:x)
    let _ = {}
    let keyvals = []
    let _.seq = timl#seq(a:x)
    while _.seq isnot# g:timl#nil
      call extend(keyvals, timl#ary(timl#first(_.seq)))
      let _.seq = timl#next(_.seq)
    endwhile
    return 'timl#hash_map('.timl#compiler#serialize(keyvals).')'

  elseif timl#setp(a:x)
    let _ = {}
    let keyvals = []
    let _.seq = timl#seq(a:x)
    while _.seq isnot# g:timl#nil
      call add(keyvals, timl#first(_.seq))
      let _.seq = timl#next(_.seq)
    endwhile
    return 'timl#set('.timl#compiler#serialize(keyvals).')'

  elseif timl#consp(a:x)
    return 'timl#cons('.timl#compiler#serialize(a:x.car).','.timl#compiler#serialize(a:x.cdr).')'

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

function! s:tempsym(...)
  let s:id = get(s:, 'id', 0) + 1
  return 'temp.'.(a:0 ? a:1 : '_').s:id
endfunction

function! s:println(file, line)
  call extend(a:file, split(a:line, "\n"))
  return a:line . "\n"
endfunction

function! s:printfln(file, ...)
  let line = call('printf', a:000)
  return s:println(a:file, line)
endfunction

function! s:build_map(file, ns, locals, map) abort
  let _ = {}
  let sym = s:tempsym('map')
  call s:println(a:file, 'let '.sym."_ary = []")
  let _.seq = timl#seq(a:map)
  while _.seq isnot# g:timl#nil
    let _.first = timl#first(_.seq)
    call s:emit(a:file, "call add(".sym."_ary, %s)", a:ns, a:locals, _.first[0])
    call s:emit(a:file, "call add(".sym."_ary, %s)", a:ns, a:locals, _.first[1])
    let _.seq = timl#next(_.seq)
  endwhile
  call s:println(a:file, "let ".sym." = timl#hash_map(".sym."_ary)")
  return sym
endfunction

function! s:wrap_meta(file, ns, locals, sym, obj) abort
  let meta = timl#meta(a:obj)
  if meta is# g:timl#nil
    return a:sym
  else
    let sym = s:build_map(a:file, a:ns, a:locals, meta)
    return 'timl#with_meta('.a:sym.', '.sym.')'
  endif
endfunction

function! s:emit(file, context, ns, locals, x) abort
  let _ = {}
  let X = a:x
  if timl#symbolp(X)
    if has_key(a:locals, X[0])
      return s:printfln(a:file, a:context, "locals[0][".string(X[0])."]")
    elseif X[0] =~# '^$\w\+$'
      return s:printfln(a:file, a:context, "(exists('".X[0]."') ? ".X[0]." : g:timl#nil)")
    else
      return s:printfln(a:file, a:context, timl#compiler#resolve(X[0], a:ns))
    endif

  elseif type(X) == type([]) && X isnot# g:timl#nil
    let sym = s:tempsym('vec')
    call s:println(a:file, 'let '.sym." = []")
    for _.e in X
      call s:emit(a:file, "call add(".sym.", %s)", a:ns, a:locals, _.e)
    endfor
    if islocked('X')
      call s:println(a:file, "let ".sym." = timl#persistentb(".sym.")")
    endif
    return s:printfln(a:file, a:context, sym)

  elseif timl#mapp(X)
    return s:printfln(a:file, a:context,
          \ s:wrap_meta(a:file, a:ns, a:locals, s:build_map(a:file, a:ns, a:locals, X), X))

  elseif timl#setp(X)
    let sym = s:tempsym('set')
    call s:println(a:file, 'let '.sym."_ary = []")
    let _.seq = timl#seq(X)
    while _.seq isnot# g:timl#nil
      let _.first = timl#first(_.seq)
      call s:emit(a:file, "call add(".sym."_ary, %s)", a:ns, a:locals, _.first)
      let _.seq = timl#next(_.seq)
    endwhile
    call s:println(a:file, "let ".sym." = timl#set(".sym."_ary)")
    return s:printfln(a:file, a:context,
          \ s:wrap_meta(a:file, a:ns, a:locals, sym, X))

  elseif !timl#consp(X)
    return s:printfln(a:file, a:context, timl#compiler#serialize(X))

  endif

  let F = timl#first(X)
  let rest = timl#rest(X)
  let args = timl#ary(rest)

  if timl#symbolp(F, ':')
    return call('timl#compiler#emit__COLON_', [a:file, a:context, a:ns, X, a:locals] + args)
  elseif timl#symbolp(F, '.')
    return call('timl#compiler#emit__DOT_', [a:file, a:context, a:ns, X, a:locals] + args)
  elseif timl#symbolp(F) && exists('*timl#compiler#emit_'.timl#munge(F))
    return call("timl#compiler#emit_".timl#munge(F), [a:file, a:context, a:ns, X, a:locals] + args)
  endif

  let tmp = s:tempsym('invoke')
  if timl#symbolp(F) && !has_key(a:locals, F[0]) && F[0] !~# '^:'
    let Fn = timl#compiler#lookup(F, a:ns)
    if timl#type(Fn) == 'timl.lang/Function' && timl#truth(get(Fn, 'macro', g:timl#nil))
      return s:emit(a:file, a:context, a:ns, a:locals, timl#call(Fn, [X, a:locals] + args))
    endif
  endif
  call s:emit(a:file, "let ".tmp."_args = %s", a:ns, a:locals, args)
  call s:emit(a:file, "let ".tmp."_function = %s", a:ns, a:locals, F)
  return s:printfln(a:file, a:context,
        \ 'timl#functionp('.tmp.'_function) ? '
        \ . 'call('.tmp.'_function.call, '.tmp.'_args, '.tmp.'_function) : '
        \ . 'type('.tmp.'_function) == '.type(function('tr')) . ' ? '
        \ .      'call('.tmp.'_function, '.tmp.'_args)' . ' : '
        \ . 'timl#call('.tmp.'_function, '.tmp.'_args)')
endfunction

function! timl#compiler#emit_set_BANG_(file, context, ns, form, locals, var, value) abort
  if timl#symbolp(a:var)
    let var = a:var[0]
    if var =~# '^\w:\|^&'
      let var = var[0].timl#munge(var[1:-1])
    else
      let var = timl#compiler#resolve(var, a:ns)
    endif
    if var[0][0] !=# '&'
      call s:println(a:file, 'unlet! '.var)
    endif
    call s:emit(a:file, 'let '.var.' =  %s', a:ns, a:locals, a:value)
    return s:printfln(a:file, a:context, 'g:timl#nil')
  elseif timl#consp(a:var)
    let args = timl#ary(a:var)
    if len(args) == 3 && timl#symbolp(args[0], '.')
      let tmp = s:tempsym('setq')
      call s:emit(a:file, 'let '.tmp.'_coll =  %s', a:ns, a:locals, args[1])
      call s:emit(a:file, 'let '.tmp.'_coll['.string(substitute(timl#str(args[2]), '^-', '', '')).'] =  %s', a:ns, a:locals, a:value)
      return s:printfln(a:file, a:context, 'g:timl#nil')
    endif
  endif
  throw 'timl: invalid set! form'
endfunction

function! timl#compiler#emit_function(file, context, ns, form, locals, name) abort
  return s:printfln(a:file, a:context, 'function('.string(timl#munge(a:name[0])).')')
endfunction

function! timl#compiler#emit_if(file, context, ns, form, locals, cond, then, ...) abort
  let tmp = s:tempsym('if')
  return s:emit(a:file, "let ".tmp." = %s", a:ns, a:locals, a:cond)
        \ . s:println(a:file, "if ".tmp." isnot# g:timl#nil && ".tmp." isnot# g:timl#false")
        \ . s:emit(a:file, a:context, a:ns, a:locals, a:then)
        \ . s:println(a:file, "else")
        \ . s:emit(a:file, a:context, a:ns, a:locals, a:0 ? a:1 : g:timl#nil)
        \ . s:println(a:file, "endif")
endfunction

function! timl#compiler#emit_recur(file, context, ns, form, locals, ...) abort
  if a:context ==# "return %s"
    let sym = s:tempsym('recur')
    call s:println(a:file, "let newlocals = copy(self.locals)")
    call s:emit(a:file, "call timl#compiler#arg2env(self.arglist, %s, newlocals)", a:ns, a:locals, a:000)
    call s:println(a:file, "let locals[-1] = newlocals")
    return s:println(a:file, "continue")
  endif
  throw 'timl#compiler: recur called outside tail position'
endfunction

if !exists('g:timl_functions')
  let g:timl_functions = {}
endif

function! s:loc_meta(form)
  let meta = timl#meta(a:form)
  if type(meta) == type({}) && has_key(meta, 'file') && has_key(meta, 'line')
    return {'file': meta.file, 'line': meta.line}
  else
    return {}
  endif
endfunction

function! s:function_gc()
  for fn in keys(g:timl_functions)
    try
      call function('{'.fn.'}')
    catch /^Vim.*E700/
      call remove(g:timl_functions, fn)
    endtry
  endfor
endfunction

augroup timl#compiler#fn
  autocmd!
  autocmd CursorHold * call s:function_gc()
augroup END

function! timl#compiler#emit_fn_STAR_(file, context, ns, form, locals, params, ...) abort
  let tmp = s:tempsym('fn')
  let locals = copy(a:locals)
  call s:println(a:file, "call insert(locals, copy(locals[0]))")
  call s:println(a:file, "try")
  call s:println(a:file, "let ".tmp." = timl#bless('timl.lang/Function', {'locals': locals[0], 'ns': ".string(a:ns)."})")
  if timl#symbolp(a:params)
    call s:println(a:file, "let locals[0][".string(a:params[0])."] = ".tmp)
    let locals[a:params[0]] = 1
    call s:println(a:file, "let ".tmp.".name = ".string(a:params[0]))
    let params = get(a:000, 0, [])
    let body = a:000[1:-1]
  else
    let params = a:params
    let body = a:000
  endif
  if timl#consp(params)
    return s:emit_multifn(a:file, a:context, a:ns, a:form, locals, timl#symbolp(a:params) ? a:params : [], tmp, [params] + body)
  endif
  call s:println(a:file, "let ".tmp.".arglist = ".timl#compiler#serialize(params))
  call s:println(a:file, "function! ".tmp.".call(...) abort")
  call s:println(a:file, "let temp = {}")
  call s:println(a:file, "let locals = [timl#compiler#arg2env(self.arglist, a:000, copy(self.locals))]")
  call s:println(a:file, "while 1")
  let _ = {}
  for _.param in params
    let locals[timl#str(_.param)] = 1
  endfor
  call call('timl#compiler#emit_do', [a:file, "return %s", a:ns, a:form, locals] + body)
  call s:println(a:file, "endwhile")
  call s:println(a:file, "endfunction")
  let meta = s:loc_meta(a:form)
  if !empty(meta)
    call s:println(a:file, "let g:timl_functions[join([".tmp.".call])] = "
          \ . timl#compiler#serialize(meta))
  endif
  call s:printfln(a:file, a:context, tmp)
  call s:println(a:file, "finally")
  call s:println(a:file, "call remove(locals, 0)")
  return s:println(a:file, "endtry")
endfunction

function! s:emit_multifn(file, context, ns, form, locals, name, tmp, fns)
  let _ = {}
  let dispatch = {}
  for fn in a:fns
    let _.args = timl#first(fn)
    let arity = timl#symbolp(get(_.args, -2), '&') ? 1-len(_.args) : len(_.args)
    let dispatch[arity < 0 ? 30-arity : 10 + arity] = arity
    call call('timl#compiler#emit_fn_STAR_', [a:file, "let ".a:tmp."[".string(arity)."] = %s", a:ns, a:form, a:locals, _.args] + timl#ary(timl#rest(fn)))
  endfor
  call s:println(a:file, "function! ".a:tmp.".call(...) abort")
  call s:println(a:file, "if 0")
  for arity in map(sort(keys(dispatch)), 'dispatch[v:val]')
    if arity < 0
      call s:println(a:file, "elseif a:0 >= ".(-1 - arity))
    else
      call s:println(a:file, "elseif a:0 == ".arity)
    endif
    call s:println(a:file, "return call(self[".arity."].call, a:000, self[".arity."])")
  endfor
  call s:println(a:file, "else")
  call s:println(a:file, "throw 'timl: arity error'")
  call s:println(a:file, "endif")
  call s:println(a:file, "endfunction")
  call s:printfln(a:file, a:context, a:tmp)
  call s:println(a:file, "finally")
  call s:println(a:file, "call remove(locals, 0)")
  return s:println(a:file, "endtry")
endfunction

let s:amp = timl#symbol('&')
function! timl#compiler#arg2env(arglist, args, env) abort
  let args = a:args
  let env = a:env
  let _ = {}
  let i = 0
  for _.param in timl#ary(a:arglist)
    if _.param is s:amp
      let env[get(a:arglist, i+1, ['...'])[0]] = args[i : -1]
      break
    elseif i >= len(args)
      throw 'timl: arity error: need '.timl#printer#string(a:arglist).' but got '.timl#printer#string(a:args)
    elseif timl#symbolp(_.param)
      let env[_.param[0]] = args[i]
    elseif type(_.param) == type([])
      for j in range(len(_.param))
        let key = timl#str(_.param[j])
        if type(args[i]) == type([])
          let env[key] = get(args[i], j, g:timl#nil)
        elseif type(args[i]) == type({})
          let env[key] = get(args[i], key, g:timl#nil)
        endif
      endfor
    else
      throw 'timl: unsupported param '.string(param)
    endif
    let i += 1
  endfor
  return env
endfunction

function! timl#compiler#emit_let_STAR_(file, context, ns, form, locals, bindings, ...) abort
  let _ = {}
  let locals = copy(a:locals)
  let tmp = s:tempsym('let')
  call s:println(a:file, "let ".tmp." = copy(locals[0])")
  call s:println(a:file, "try")
  call s:println(a:file, "call insert(locals, ".tmp.")")
  if timl#vectorp(a:bindings)
    let bindings = timl#ary(a:bindings)
    if len(bindings) % 2 !=# 0
      throw "timl(let): even number of forms required" . len(bindings)
    endif
    for i in range(0, len(bindings)-1, 2)
      call s:emit(a:file,
            \ "let ".tmp."[".string(timl#str(bindings[i]))."] = %s",
            \ a:ns, locals, bindings[i+1])
      let locals[timl#str(bindings[i])] = 1
    endfor
  else
    throw 'timl#compiler: bindings must be vectors'
  endif
  call call('timl#compiler#emit_do', [a:file, a:context, a:ns, a:form, locals] + a:000)
  call s:println(a:file, "finally")
  call s:println(a:file, "call remove(locals, 0)")
  return s:println(a:file, "endtry")
endfunction

function! timl#compiler#emit_do(file, context, ns, form, locals, ...) abort
  let _ = {}
  let sym = s:tempsym('trash')
  for _.x in a:000[0:-2]
    call s:emit(a:file, "let ".sym." = %s", a:ns, a:locals, _.x)
  endfor
  return s:emit(a:file, a:context, a:ns, a:locals, get(a:000, -1, g:timl#nil))
  return str
endfunction

function! timl#compiler#emit_def(file, context, ns, form, locals, sym, ...) abort
  let ns = 'timl#munge(g:timl#core#_STAR_ns_STAR_.name)'
  let var = "g:{".ns."}#".timl#munge(a:sym)
  if a:0
    call s:println(a:file, "unlet! ".var)
    call s:emit(a:file, 'let '.var.' = %s', a:ns, a:locals, a:1)
  else
    call s:println(a:file, "if !exists('g:'.".ns.".'#'.".string(timl#munge(a:sym)).")")
    call s:println(a:file, 'let '.var.' = g:timl#nil')
    call s:println(a:file, 'endif')
  endif
  return s:printfln(a:file, a:context, var)
endfunction

function! timl#compiler#emit__COLON_(file, context, ns, form, locals, ...) abort
  let tmp = s:tempsym('execute')
  call s:emit(a:file, 'let '.tmp." = %s", a:ns, a:locals, a:000)
  call s:println(a:file, "execute join(".tmp.", ' ')")
  return s:printfln(a:file, a:context, "g:timl#nil")
endfunction

function! timl#compiler#emit__DOT_(file, context, ns, form, locals, obj, fn, ...) abort
  let tmp = s:tempsym('dot')
  let fn = timl#str(a:fn)
  call s:emit(a:file, 'let '.tmp."_obj = %s", a:ns, a:locals, a:obj)
  if fn =~# '^-'
    return s:printfln(a:file, a:context, tmp.'_obj['.string(fn[1:-1]).']')
  endif
  call s:emit(a:file, 'let '.tmp."_args = %s", a:ns, a:locals, a:000)
  return s:printfln(a:file, a:context, 'timl#call('.tmp.'_obj['.string(timl#str(a:fn)).'], '.tmp.'_args, '.tmp.'_obj)')
endfunction

function! timl#compiler#emit_quote(file, context, ns, form, locals, elem) abort
  return s:printfln(a:file, a:context, timl#compiler#serialize(a:elem))
endfunction

let s:catch   = timl#symbol('catch')
let s:finally = timl#symbol('finally')
function! timl#compiler#emit_try(file, context, ns, form, locals, ...) abort
  let _ = {}
  let tmp = s:tempsym('try')
  call s:println(a:file, 'try')
  call s:println(a:file, 'let '.tmp.' = g:timl#nil')
  let i = -1
  for i in range(a:0)
    let _.e = a:000[i]
    if timl#consp(_.e) && (timl#first(_.e) is s:catch || timl#first(_.e) is s:finally)
      let i -= 1
      break
    endif
    call s:emit(a:file, 'let '.tmp.' = %s', a:ns, a:locals, _.e)
  endfor
  call s:printfln(a:file, a:context, tmp)
  for i in range(i+1, a:0-1)
    let _.e = a:000[i]
    if timl#consp(_.e) && timl#first(_.e) is s:finally
      call s:println(a:file, 'finally')
      call call('timl#compiler#emit_do', [a:file, 'let '.tmp.' = %s', a:ns, a:form, a:locals] + timl#ary(timl#rest(_.e)))
    elseif timl#consp(_.e) && timl#first(_.e) is s:catch
      let rest = timl#ary(timl#rest(_.e))
      let _.pattern = rest[0]
      if type(_.pattern) == type(0)
        let _.pattern = '^Vim\%((\a\+)\)\=:E' . _.pattern
      endif
      let var = rest[1]
      call s:println(a:file, 'catch /'._.pattern.'/')
      call s:println(a:file, "call insert(locals, copy(locals[0]))")
      call s:println(a:file, "try")
      call s:println(a:file, "let locals[0][".string(var[0])."] = timl#build_exception(v:exception, v:throwpoint)")
      let locals = copy(a:locals)
      let locals[var[0]] = 1
      call call('timl#compiler#emit_do', [a:file, a:context, a:ns, a:form, locals] + rest[2:-1])
      call s:println(a:file, "finally")
      call s:println(a:file, "call remove(locals, 0)")
      call s:println(a:file, "endtry")
    else
      throw 'timl#compiler: invalid form in try after first catch/finally'
    endif
  endfor
  return s:println(a:file, 'endtry')
endfunction

function! timl#compiler#emit_throw(file, context, ns, form, locals, str) abort
  call s:emit(a:file, "throw %s", a:ns, a:locals, a:str)
endfunction

" }}}1
" Section: Execution {{{1

if !exists('g:timl#namespaces')
  let g:timl#namespaces = {
        \ 'timl.core': timl#bless('timl.lang/Namespace', {'name': timl#symbol('timl.core'), 'referring': [], 'aliases': {}}),
        \ 'user':      timl#bless('timl.lang/Namespace', {'name': timl#symbol('user'), 'referring': [timl#symbol('timl.core')], 'aliases': {}})}
endif

if !exists('g:timl#core#_STAR_ns_STAR_')
  let g:timl#core#_STAR_ns_STAR_ = g:timl#namespaces['user']
endif

function! timl#compiler#build(x, context, ns, ...) abort
  let file = []
  call s:emit(file, a:context, a:ns, a:0 ? a:1 : {}, a:x)
  return join(file, "\n") . "\n"
endfunction

function! timl#compiler#eval(x, ...) abort
  let ns = a:0 ? a:1 : g:timl#core#_STAR_ns_STAR_
  let str = timl#compiler#build(a:x, "return %s", ns, a:0 > 1 ? a:2 : {})
  return s:execute(a:x, str, a:0 > 1 ? a:2 : {})
endfunction

function! s:execute(form, str, ...)
  let _dict = {}
  let _str = "function _dict.func(locals) abort\n"
        \ . "let locals=[a:locals]\n"
        \ . "let temp={}\n"
        \ . "while 1\n"
        \ . a:str
        \ . "endwhile\n"
        \ . "endfunction"
  execute _str
  let meta = s:loc_meta(a:form)
  if !empty(meta)
    let g:timl_functions[join([_dict.func])] = meta
  endif
  return _dict.func(a:0 ? a:1 : {})
endfunction

let s:dir = (has('win32') ? '$APPCACHE/Vim' :
      \ match(system('uname'), "Darwin") > -1 ? '~/Library/Vim' :
      \ empty($XDG_CACHE_HOME) ? '~/.cache/vim' : '$XDG_CACHE_HOME/vim').'/timl'

function! s:cache_filename(file)
  let base = expand(s:dir)
  if !isdirectory(base)
    call mkdir(base, 'p')
  endif
  let filename = tr(substitute(fnamemodify(a:file, ':p:~'), '^\~.', '', ''), '\/:', '%%%') . '.vim'
  return base . '/' . filename
endfunction

let s:myftime = getftime(expand('<sfile>'))

function! timl#compiler#source_file(filename)
  let old_ns = g:timl#core#_STAR_ns_STAR_
  let cache = s:cache_filename(a:filename)
  try
    let g:timl#core#_STAR_ns_STAR_ = g:timl#namespaces['user']
    let ftime = getftime(cache)
    if !exists('$TIML_EXPIRE_CACHE') && ftime > getftime(a:filename) && ftime > s:myftime
      try
        execute 'source '.fnameescape(cache)
      catch
        let error = 1
      endtry
      if !exists('error')
        return
      endif
    endif
    let file = timl#reader#open(a:filename)
    let strs = ["let s:d = {}"]
    let _ = {}
    let _.read = g:timl#nil
    let eof = []
    while _.read isnot# eof
      let _.read = timl#reader#read(file, eof)
      let str = timl#compiler#build(_.read, 'return %s', g:timl#core#_STAR_ns_STAR_)
      call s:execute(_.read, str)
      call add(strs, "function! s:d.f() abort\nlet locals = [{}]\nlet temp ={}\n".str."endfunction\n")
      let meta = s:loc_meta(_.read)
      if !empty(meta)
        let strs[-1] .= 'let g:timl_functions[join([s:d.f])] = '.string(meta)."\n"
      endif
      let strs[-1] .= "call s:d.f()\n"
    endwhile
    call add(strs, 'unlet s:d')
    call writefile(split(join(strs, "\n"), "\n"), cache)
  catch /^Vim\%((\a\+)\)\=:E168/
  finally
    let g:timl#core#_STAR_ns_STAR_ = old_ns
    if exists('file')
      call timl#reader#close(file)
    endif
  endtry
endfunction

call timl#require('timl.core')

" }}}1
" Section: Tests {{{1

if !$TIML_TEST
  finish
endif

function! s:re(str)
  try
    return timl#compiler#eval(timl#reader#read_string(a:str))
  endtry
endfunction

command! -nargs=1 TimLCAssert
      \ try |
      \   if !eval(<q-args>) |
      \     echomsg "Failed: ".<q-args> |
      \   endif |
      \ catch /.*/ |
      \  echomsg "Error:  ".<q-args>." (".v:exception.") @ " . v:throwpoint |
      \ endtry

TimLCAssert s:re('(let* [x 42] (def forty-two x))')
TimLCAssert s:re('forty-two') ==# 42

TimLCAssert s:re('(if true forty-two 69)') ==# 42
TimLCAssert s:re('(if false "boo" "yay")') ==# "yay"
TimLCAssert s:re('(do 1 2)') ==# 2

TimLCAssert empty(s:re('(set! g:timl_setq (dict))'))
TimLCAssert g:timl_setq ==# {}
let g:timl_setq = {}
TimLCAssert empty(s:re('(set! (. g:timl_setq key) ["a" "b"])'))
TimLCAssert g:timl_setq ==# {"key": ["a", "b"]}
unlet! g:timl_setq

TimLCAssert s:re("((fn* [n f] (if (<= n 1) f (recur (- n 1) (* f n)))) 5 1)") ==# 120

delcommand TimLCAssert

" }}}1

" vim:set et sw=2:
