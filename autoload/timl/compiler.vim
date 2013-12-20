" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_compiler')
  finish
endif
let g:autoloaded_timl_compiler = 1

" Section: Symbol resolution

let s:specials = {
      \ 'if': 1,
      \ 'do': 1,
      \ 'let*': 1,
      \ 'fn*': 1,
      \ 'def': 1,
      \ 'set!': 1,
      \ 'execute': 1,
      \ '.': 1,
      \ 'quote': 1,
      \ 'function': 1,
      \ 'var': 1,
      \ 'throw': 1,
      \ 'try': 1,
      \ 'catch': 1,
      \ 'finally': 1}

function! timl#compiler#specialp(sym)
  return has_key(s:specials, timl#str(a:sym))
endfunction

function! timl#compiler#resolve(sym) abort
  if a:sym[0] =~# '^\w:'
    return {'location': timl#munge(a:sym[0])}
  elseif a:sym[0][0] ==# '$'
    return {'location': "(exists('".a:sym[0]."') ? ".a:sym[0]." : g:timl#nil)"}
  elseif (a:sym[0] =~# '^&\w' && exists(a:sym[0]))
    return {'location': a:sym[0]}
  endif
  let var = timl#namespace#maybe_resolve(g:timl#core#_STAR_ns_STAR_, a:sym)
  if var isnot# g:timl#nil
    return var
  endif
  throw "timl#compiler: could not resolve ".timl#str(a:sym)
endfunction

" Section: Macroexpand

let s:kmacro = timl#keyword#intern('macro')
function! timl#compiler#macroexpand_1(form) abort
  if timl#cons#test(a:form) && timl#symbol#test(timl#first(a:form)) && !timl#compiler#specialp(timl#first(a:form))
    let var = timl#namespace#maybe_resolve(g:timl#core#_STAR_ns_STAR_, timl#first(a:form))
    if var isnot# g:timl#nil && timl#truth(timl#coll#get(var.meta, s:kmacro))
      return timl#call(timl#var#get(var), [a:form, {}] + timl#ary(timl#next(a:form)))
    endif
  endif
  return a:form
endfunction

function! timl#compiler#macroexpand_all(form) abort
  let _ = {'last': g:timl#nil, 'this': a:form}
  while _.last isnot# _.this
    let [_.last, _.this] = [_.this, timl#compiler#macroexpand_1(_.this)]
  endwhile
  return _.this
endfunction

" Section: Serialization

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
  if timl#keyword#test(a:x)
    return 'timl#keyword#intern('.timl#compiler#serialize(a:x[0]).')'

  elseif timl#symbol#test(a:x)
    if has_key(a:x, 'meta')
      return 'timl#symbol#intern_with_meta('.timl#compiler#serialize(a:x[0]).', '.timl#compiler#serialize(a:x.meta).')'
    else
      return 'timl#symbol#intern('.timl#compiler#serialize(a:x[0]).')'
    endif

  elseif a:x is# g:timl#nil
    return 'g:timl#nil'

  elseif a:x is# g:timl#false
    return 'g:timl#false'

  elseif a:x is# g:timl#true
    return 'g:timl#true'

  elseif a:x is# g:timl#empty_list
    return 'g:timl#empty_list'

  elseif type(a:x) == type([])
    return 'timl#array#lock(['.join(map(copy(a:x), 'timl#compiler#serialize(v:val)'), ', ').'])'

  elseif timl#mapp(a:x) && timl#type(a:x) !=# 'vim/Dictionary'
    let _ = {}
    let keyvals = []
    let _.seq = timl#seq(a:x)
    while _.seq isnot# g:timl#nil
      call extend(keyvals, timl#ary(timl#first(_.seq)))
      let _.seq = timl#next(_.seq)
    endwhile
    return 'timl#map#create('.timl#compiler#serialize(keyvals).')'

  elseif timl#setp(a:x)
    let _ = {}
    let keyvals = []
    let _.seq = timl#seq(a:x)
    while _.seq isnot# g:timl#nil
      call add(keyvals, timl#first(_.seq))
      let _.seq = timl#next(_.seq)
    endwhile
    return 'timl#set#create('.timl#compiler#serialize(keyvals).')'

  elseif timl#cons#test(a:x)
    return 'timl#cons#create('
          \ . timl#compiler#serialize(a:x.car).','
          \ . timl#compiler#serialize(a:x.cdr)
          \ . (has_key(a:x, 'meta') ? ',' . timl#compiler#serialize(a:x.meta) : '').')'

  elseif timl#var#test(a:x)
    return 'timl#var#find('.timl#compiler#serialize(timl#symbol#intern(a:x.str)).')'

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

" Section: Emission

function! s:emitln(file, str)
  call add(a:file, a:str)
  return a:file
endfunction

function! s:localfy(name) abort
  return a:name =~# '^\h\w*$' ? 'locals.'.a:name :  'locals['.string(a:name).']'
endfunction

function! s:with_context(env, context) abort
  let env = copy(a:env)
  let env.context = a:context
  return env
endfunction

function! s:copy_locals(env) abort
  let env = copy(a:env)
  let env.locals = copy(a:env.locals)
  return env
endfunction

function! s:tempsym(...)
  let s:id = get(s:, 'id', 0) + 1
  return (a:0 ? a:1 : '_').s:id
endfunction

function! s:let_tmp(file, clue, str)
  let temp = s:tempsym(a:clue)
  call s:emitln(a:file, 'let '.temp.' = '.a:str)
  return temp
endfunction

function! s:wrap_as_expr(file, env, form) abort
  let env = s:with_context(a:env, 'return')
  if has_key(env, 'params')
    call remove(env, 'params')
  endif
  let temp = s:let_tmp(a:file, 'thunk', '{"locals": copy(locals)}')
  call s:emitln(a:file, "function ".temp.".call() abort")
  call s:emitln(a:file, "let locals = self.locals")
  call s:emit(a:file, env, a:form)
  call s:emitln(a:file, "endfunction")
  return temp.'.call()'
endfunction

function! s:expr_sf_let_STAR_(file, env, form) abort
  return s:wrap_as_expr(a:file, a:env, a:form)
endfunction

function! s:add_local(env, sym) abort
  let str = timl#symbol#cast(a:sym)[0]
  let a:env.locals[str] = s:localfy(str)
endfunction

function! s:emit_sf_let_STAR_(file, env, form) abort
  if a:env.context ==# 'statement'
    return s:emitln(a:file, 'call '.s:wrap_as_expr(a:file, a:env, a:form))
  endif
  let ary = timl#ary(timl#fnext(a:form))
  let env = s:copy_locals(a:env)
  for i in range(0, len(ary)-1, 2)
    let expr = s:emit(a:file, s:with_context(env, 'expr'), ary[i+1])
    call s:emitln(a:file, 'let '.s:localfy(timl#symbol#cast(ary[i])[0]).' = '.expr)
    call s:add_local(env, ary[i])
  endfor
  let body = timl#nnext(a:form)
  if timl#coll#count(body) == 1
    return s:emit(a:file, env, timl#first(body))
  else
    return s:emit_sf_do(a:file, env, timl#cons#create(timl#symbol('do'), body))
  endif
endfunction

function! s:expr_sf_do(file, env, form) abort
  return s:wrap_as_expr(a:file, a:env, a:form)
endfunction

function! s:emit_sf_do(file, env, form) abort
  let ary = timl#ary(timl#next(a:form))
  if empty(ary)
    return s:emit(a:file, a:env, g:timl#nil)
  endif
  for i in range(len(ary) - 1)
    call s:emit(a:file, s:with_context(a:env, 'statement'), ary[i])
  endfor
  call s:emit(a:file, a:env, ary[-1])
endfunction

function! s:expr_sf_if(file, env, form)
  let ary = timl#ary(timl#next(a:form))
  return 'timl#truth('.s:emit(a:file, a:env, ary[0]) . ')'
        \ . ' ? ' . s:emit(a:file, a:env, get(ary, 1, g:timl#nil))
        \ . ' : ' . s:emit(a:file, a:env, get(ary, 2, g:timl#nil))
endfunction

function! s:emit_sf_if(file, env, form) abort
  let ary = timl#ary(timl#next(a:form))
  call s:emitln(a:file, 'if timl#truth('.s:expr(a:file, a:env, ary[0]).')')
  call s:emit(a:file, a:env, get(ary, 1, g:timl#nil))
  call s:emitln(a:file, 'else')
  call s:emit(a:file, a:env, get(ary, 2, g:timl#nil))
  call s:emitln(a:file, 'endif')
endfunction

function! s:expr(file, env, form) abort
  return s:emit(a:file, s:with_context(a:env, 'expr'), a:form)
endfunction

function! s:expr_sf_quote(file, env, form) abort
  return timl#compiler#serialize(timl#fnext(a:form))
endfunction

function! s:expr_sf_function(file, env, form) abort
  return "function(".timl#compiler#serialize(timl#str(timl#fnext(a:form))).")"
endfunction

function! s:expr_sf_var(file, env, form) abort
  let sym = timl#symbol#cast(timl#fnext(a:form))
  let var = timl#namespace#maybe_resolve(g:timl#core#_STAR_ns_STAR_, sym)
  if var isnot# g:timl#nil
    return timl#compiler#serialize(var)
  endif
  throw "timl#compiler: could not resolve ".timl#str(sym)
endfunction

function! s:one_fn(file, env, form, name, temp, catch_errors) abort
  let env = s:copy_locals(a:env)
  let args = timl#ary(timl#first(a:form))
  let env.params = args
  let body = timl#next(a:form)
  let _ = {}
  let positional = []
  let arity = 0
  for _.arg in args
    if timl#symbol#is(_.arg, '&')
      call s:add_local(env, args[-1])
      let rest = env.locals[args[-1][0]]
      let arity += 1000
      break
    else
      call s:add_local(env, _.arg)
      call add(positional, env.locals[_.arg[0]])
      let arity += 1
    endif
  endfor
  call s:emitln(a:file, "function ".a:temp."(_) abort")
  call s:emitln(a:file, "let locals = copy(self.locals)")
  if len(a:name)
    call s:emitln(a:file, 'let '.s:localfy(a:name).' = self')
  endif
  if a:catch_errors && !empty(positional)
    call s:emitln(a:file, 'try')
  endif
  if !empty(positional)
    call s:emitln(a:file, "let [".join(positional, ', ').(exists('rest') ? '; '.rest : '')."] = a:_")
  elseif exists('rest')
    call s:emitln(a:file, "let ".rest." = a:_")
  endif
  if a:catch_errors && !empty(positional)
    call s:emitln(a:file, 'catch /^Vim(let):E68[78]:/')
    call s:emitln(a:file, "throw 'timl: arity error'")
    call s:emitln(a:file, 'endtry')
  endif
  let c = 0
  call s:emitln(a:file, "while 1")
  if timl#coll#count(body) == 1
    call s:emit(a:file, s:with_context(env, 'return'), timl#first(body))
  else
    call s:emit_sf_do(a:file, s:with_context(env, 'return'), timl#cons#create(timl#symbol('do'), body))
  endif
  call s:emitln(a:file, "break")
  call s:emitln(a:file, "endwhile")
  call s:emitln(a:file, "endfunction")
  return arity
endfunction

function! s:expr_sf_fn_STAR_(file, env, form) abort
  let env = s:copy_locals(a:env)
  let _ = {}
  let _.next = timl#next(a:form)
  if timl#symbol#test(timl#first(_.next))
    let name = timl#first(_.next)[0]
    let env.locals[name] = s:localfy(name)
    let _.next = timl#next(_.next)
  else
    let name = ''
  endif
  let temp = s:let_tmp(a:file, 'fn', 'timl#bless("timl.lang/Function", {"ns": g:timl#core#_STAR_ns_STAR_, "locals": copy(locals)})')
  if !empty(name)
    call s:emitln(a:file, 'let '.temp.'.name = timl#symbol('.string(name).')')
  endif
  if timl#vectorp(timl#first(_.next))
    call s:one_fn(a:file, env, _.next, name, temp.'.apply', 1)
  elseif timl#cons#test(timl#first(_.next))
    let c = char2nr('a')
    let fns = {}
    while _.next isnot# g:timl#nil
      let fns[s:one_fn(a:file, env, timl#first(_.next), name, temp.'.'.nr2char(c), 0)] = nr2char(c)
      let _.next = timl#next(_.next)
      let c += 1
    endwhile
    call s:emitln(a:file, "function ".temp.".apply(_) abort")
    call s:emitln(a:file, "if 0")
    for arity in sort(map(keys(fns), 'printf("%04d", v:val)'))
      if arity >= 1000
        call s:emitln(a:file, "elseif len(a:_) >= ".(arity-1000))
      else
        call s:emitln(a:file, "elseif len(a:_) == ".str2nr(arity))
      endif
      call s:emitln(a:file, 'return self.'.fns[str2nr(arity)]. '(a:_)')
    endfor
    call s:emitln(a:file, "else")
    call s:emitln(a:file, "throw 'timl: arity error'")
    call s:emitln(a:file, "endif")
    call s:emitln(a:file, "endfunction")
  endif
  let meta = timl#compiler#location_meta(a:env.file, a:form)
  if !empty(meta)
    call s:emitln(a:file, 'let g:timl_functions[join(['.temp.'.apply])] = '.timl#compiler#serialize(meta))
  endif
  return temp
endfunction

function! s:emit_sf_recur(file, env, form) abort
  if a:env.context !=# 'return' || !has_key(a:env, 'params')
    throw 'timl#compiler: recur outside of tail position'
  endif
  let bindings = map(copy(a:env.params), 'a:env.locals[v:val[0]]')
  call s:emitln(a:file, 'let ['.join(bindings, ', ').'] = '.s:expr(a:file, a:env, timl#ary(timl#next(a:form))))
  call s:emitln(a:file, 'continue')
endfunction

function! s:expr_sf_execute(file, env, form) abort
  return s:wrap_as_expr(a:file, a:env, a:form)
endfunction

function! s:emit_sf_execute(file, env, form) abort
  let expr = map(copy(timl#ary(timl#next(a:form))), 's:expr(a:file, a:env, v:val)')
  call s:emitln(a:file, 'execute '.join(expr, ' '))
  return s:emit(a:file, a:env, g:timl#nil)
endfunction

function! s:expr_sf_try(file, env, form) abort
  return s:wrap_as_expr(a:file, a:env, a:form)
endfunction

function! timl#compiler#build_exception(exception, throwpoint)
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
  return timl#type#bless('timl.lang/Exception', dict)
endfunction

function! s:emit_sf_try(file, env, form) abort
  if a:env.context ==# 'statement'
    return s:emitln(a:file, 'call '.s:wrap_as_expr(a:file, a:env, a:form))
  endif
  call s:emitln(a:file, 'try')
  let _ = {}
  let _.seq = timl#next(a:form)
  let body = []
  while _.seq isnot# g:timl#nil
    if timl#cons#test(timl#first(_.seq))
      let _.sym = timl#ffirst(_.seq)
      if timl#symbol#is(_.sym, 'catch') || timl#symbol#is(_.sym, 'finally')
        break
      endif
    endif
    call add(body, timl#first(_.seq))
    let _.seq = timl#next(_.seq)
  endwhile
  if timl#coll#count(body) == 1
    call s:emit(a:file, a:env, timl#first(body))
  else
    call s:emit_sf_do(a:file, a:env, timl#cons#create(timl#symbol('do'), body))
  endif
  while _.seq isnot# g:timl#nil
    let _.first = timl#first(_.seq)
    if timl#cons#test(_.first) && timl#symbol#is(timl#first(_.first), 'catch')
      call s:emitln(a:file, 'catch /'.escape(timl#fnext(_.first), '/').'/')
      let var = timl#first(timl#nnext(_.first))
      let env = s:copy_locals(a:env)
      if timl#symbol#test(var) && var[0] !=# '_'
        call s:add_local(env, var)
        call s:emitln(a:file, 'let '.env.locals[var[0]].' = timl#compiler#build_exception(v:exception, v:throwpoint)')
      endif
      call s:emit_sf_do(a:file, env, timl#cons#create(timl#symbol('do'), timl#next(timl#nnext(_.first))))
    elseif timl#cons#test(_.first) && timl#symbol#is(timl#first(_.first), 'finally')
      call s:emitln(a:file, 'finally')
      call s:emit_sf_do(a:file, s:with_context(a:env, 'statement'), timl#cons#create(timl#symbol('do'), timl#next(_.first)))
    else
      throw 'timl#compiler: invalid form after catch or finally try'
    endif
    let _.seq = timl#next(_.seq)
  endwhile
  call s:emitln(a:file, 'endtry')
endfunction

function! s:expr_sf_throw(file, env, form) abort
  return s:wrap_as_expr(a:file, a:env, a:form)
endfunction

function! s:emit_sf_throw(file, env, form) abort
  call s:emitln(a:file, 'throw '.s:expr(a:file, a:env, timl#fnext(a:form)))
endfunction

function! s:expr_sf_set_BANG_(file, env, form) abort
  let target = timl#fnext(a:form)
  let rest = timl#nnext(a:form)
  if timl#symbol#test(target)
    let var = timl#compiler#resolve(target).location
    if rest isnot# g:timl#nil
      let val = s:expr(a:file, a:env, timl#first(rest))
      if var !~# '^[&$]'
        call s:emitln(a:file, 'unlet! '.var)
      endif
      call s:emitln(a:file, 'let '.var.' = '.val)
    else
      call s:emitln(a:file, 'if !exists('.string(var).')')
      call s:emitln(a:file, 'let '.var.' = g:timl#nil')
      call s:emitln(a:file, 'endif')
    endif
    return var
  elseif timl#cons#test(target) && timl#symbol#is(timl#first(target), '.')
    let key = substitute(timl#str(timl#first(timl#nnext(target))), '^-', '', '')
    let target2 = timl#symbol#cast(timl#fnext(target))
    if has_key(a:env.locals, target2[0])
      let var = a:env.locals[target2[0]]
    else
      let var = timl#compiler#resolve(target2).location
    endif
    let val = s:expr(a:file, a:env, timl#first(rest))
    call s:emitln(a:file, 'let '.var.'['.timl#compiler#serialize(key).'] = '.val)
    return var.'['.timl#compiler#serialize(key).']'
  else
    throw 'timl#compiler: unsupported set! form'
  endif
endfunction

let s:kline = timl#keyword#intern('line')
let s:kfile = timl#keyword#intern('file')
function! s:expr_sf_def(file, env, form) abort
  let rest = timl#next(a:form)
  let var = timl#symbol#cast(timl#first(rest))
  if has_key(a:env, 'file')
    let var = timl#meta#vary(var, g:timl#core#assoc, s:kline, a:env.line, s:kfile, a:env.file)
  endif
  if timl#next(rest) isnot# g:timl#nil
    let val = s:expr(a:file, a:env, timl#fnext(rest))
    return 'timl#namespace#intern(g:timl#core#_STAR_ns_STAR_, '.timl#compiler#serialize(var).', '.val.')'
  else
    return 'timl#namespace#intern(g:timl#core#_STAR_ns_STAR_, '.timl#compiler#serialize(var).')'
  endif
endfunction

function! s:expr_dot(file, env, form) abort
  let val = s:expr(a:file, a:env, timl#fnext(a:form))
  let key = timl#first(timl#nnext(a:form))
  if timl#seqp(key)
    return val.'['.timl#compiler#serialize(timl#str(timl#first(key))).']('.s:expr_args(a:file, a:env, timl#next(key)).')'
  else
    return val.'['.timl#compiler#serialize(timl#str(key)).']'
  endif
endfunction

function! s:expr_map(file, env, form)
  let kvs = []
  let _ = {'seq': timl#seq(a:form)}
  while _.seq isnot# g:timl#nil
    call extend(kvs, timl#ary(timl#first(_.seq)))
    let _.seq = timl#next(_.seq)
  endwhile
  return 'timl#map#create(['.join(map(kvs, 's:emit(a:file, s:with_context(a:env, "expr"), v:val)'), ', ').'])'
endfunction

function! s:expr_args(file, env, form)
  return join(map(copy(timl#ary(a:form)), 's:emit(a:file, s:with_context(a:env, "expr"), v:val)'), ', ')
endfunction

function! s:emit(file, env, form) abort
  let env = a:env
  try
    if timl#cons#test(a:form)
      if has_key(a:form, 'meta') && has_key(a:form.meta, 'line')
        let env = copy(env)
        let env.line = a:form.meta.line
      endif
      let First = timl#first(a:form)
      if timl#symbol#is(First, '.')
        let expr = s:expr_dot(a:file, env, a:form)
      elseif timl#symbol#test(First)
        let munged = timl#munge(First[0])
        if env.context ==# 'expr' && exists('*s:expr_sf_'.munged)
          let expr = s:expr_sf_{munged}(a:file, env, a:form)
        elseif exists('*s:emit_sf_'.munged)
          return s:emit_sf_{munged}(a:file, env, a:form)
        elseif exists('*s:expr_sf_'.munged)
          let expr = s:expr_sf_{munged}(a:file, env, a:form)
        else
          if has_key(env.locals, First[0])
            let resolved = env.locals[First[0]]
          else
            let var = timl#compiler#resolve(First)
            if has_key(var, 'meta') && timl#truth(timl#coll#get(var.meta, s:kmacro))
              let E = timl#call(timl#var#get(var), [a:form, env] + timl#ary(timl#next(a:form)))
              return s:emit(a:file, env, E)
            endif
            let resolved = var.location
          endif
          let args = s:expr_args(a:file, env, timl#next(a:form))
          let expr = 'timl#call('.resolved.', ['.args.'])'
        endif
      else
        let args = s:expr_args(a:file, env, timl#next(a:form))
        if timl#cons#test(First) && timl#symbol#is(timl#first(First), 'function')
          let expr = timl#munge(timl#fnext(First)).'('.args.')'
        else
          let expr = 'timl#call('.s:expr(a:file, env, First).', ['.args.'])'
        endif
      endif
    elseif timl#symbol#test(a:form)
      if has_key(env.locals, a:form[0])
        let expr = env.locals[a:form[0]]
      else
        let expr = timl#compiler#resolve(a:form).location
      endif
    elseif type(a:form) == type([]) && a:form isnot# g:timl#nil
      let expr = 'timl#array#lock(['.s:expr_args(a:file, env, a:form).'])'

    elseif timl#vectorp(a:form)
      let expr = 'timl#vec(['.join(map(copy(timl#ary(a:form)), 's:emit(a:file, s:with_context(env, "expr"), v:val)'), ', ').'])'

    elseif timl#setp(a:form)
      let expr = 'timl#set(['.join(map(copy(timl#ary(a:form)), 's:emit(a:file, s:with_context(env, "expr"), v:val)'), ', ').'])'

    elseif timl#mapp(a:form)
      let expr = s:expr_map(a:file, env, a:form)
      if timl#type#string(a:form) == 'vim/Dictionary'
        let expr = substitute(expr, '\C#map#', '#dictionary#', '')
      endif

    else
      let expr = timl#compiler#serialize(a:form)
    endif
    if env.context == 'return'
      call s:emitln(a:file, 'return '.expr)
      return ''
    elseif env.context == 'statement'
      if expr =~# '^[[:alnum:]_#]\+('
        call s:emitln(a:file, 'call '.expr)
      endif
      return ''
    else
      return expr
    endif
  catch /^timl#compiler:/
    let throw = v:exception
    if throw !~# ' on line'
      let throw .= ' in ' . env.file . ' on line ' .env.line
    endif
    throw throw
  endtry
endfunction

if !exists('g:timl_functions')
  let g:timl_functions = {}
endif

function! timl#compiler#location_meta(file, form)
  let meta = timl#meta(a:form)
  if type(meta) == type({}) && has_key(meta, 'line') && a:file isnot# 'NO_SOURCE_PATH'
    return {'file': a:file, 'line': meta.line}
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

" Section: Compilation

function! timl#compiler#build(x, ...) abort
  let filename = a:0 ? a:1 : 'NO_SOURCE_PATH'
  let file = []
  call s:emit(file, {'file': filename, 'line': 1, 'context': 'return', 'locals': {}}, a:x)
  let body = join(file, "\n")."\n"
  let s:dict = {}
  let str = "function s:dict.call() abort\n"
        \ . "let locals = {}\n"
        \ . "while 1\n"
        \ . body
        \ . "endwhile\n"
        \ . "endfunction"
  execute str
  let meta = timl#compiler#location_meta(filename, a:x)
  if !empty(meta)
    let g:timl_functions[join([s:dict.call])] = meta
  endif
  return {'body': body, 'call': s:dict.call}
endfunction

" vim:set et sw=2:
