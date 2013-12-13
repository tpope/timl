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
  let the_ns = timl#namespace#the(a:ns)
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

function! timl#compiler#ns_resolve(ns, sym, ...) abort
  if has_key(a:0 ? a:1 : {}, timl#str(a:sym))
    return g:timl#nil
  endif
  let sym = timl#compiler#qualify(a:sym, a:ns, g:timl#nil)
  if sym is# g:timl#nil
    return sym
  elseif sym =~# '^[&$]'
    return sym
  elseif sym =~# '^\w:'
    return timl#munge(sym)
  else
    return timl#munge('g:'.sym)
  endif
endfunction

function! timl#compiler#resolve_or_throw(sym)
  let var = timl#compiler#ns_resolve(g:timl#core#_STAR_ns_STAR_, a:sym)
  if var isnot# g:timl#nil
    return var
  endif
  throw "timl#compiler: could not resolve ".timl#str(a:sym)
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

function! timl#compiler#serialize(x, ...)
  " TODO: guard against recursion
  if !a:0
    let meta = timl#meta(a:x)
    if !empty(meta)
      return 'timl#with_meta('.timl#compiler#serialize(a:x, 'nometa').', '.timl#compiler#serialize(meta).')'
    endif
  endif
  if timl#keyword#test(a:x)
    return 'timl#keyword#intern('.timl#compiler#serialize(a:x[0]).')'

  elseif timl#symbol#test(a:x)
    return 'timl#symbol#intern('.timl#compiler#serialize(a:x[0]).')'

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
    return 'timl#cons#create('.timl#compiler#serialize(a:x.car).','.timl#compiler#serialize(a:x.cdr).')'

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

function! s:tempsym(...)
  let s:id = get(s:, 'id', 0) + 1
  return 'temp.'.(a:0 ? a:1 : '_').s:id
endfunction

function! s:emitstr(file, str)
  let a:file[-1] .= a:str
  return a:file
endfunction

function! s:emitln(file, str)
  call s:emitstr(a:file, a:str)
  call add(a:file, '')
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
  let temp = s:let_tmp(a:file, 'wrap', '{"locals": copy(locals)}')
  call s:emitln(a:file, "function ".temp.".call() abort")
  call s:emitln(a:file, "let temp = {}")
  call s:emitln(a:file, "let locals = self.locals")
  call s:emit(a:file, env, a:form)
  call s:emitln(a:file, "endfunction")
  return temp.'.call()'
endfunction

function! s:expr_sf_let_STAR_(file, env, form) abort
  return s:wrap_as_expr(a:file, a:env, a:form)
endfunction

function! s:add_local(env, sym) abort
  let str = timl#symbol#coerce(a:sym)[0]
  let a:env.locals[str] = s:localfy(str)
endfunction

function! s:emit_sf_let_STAR_(file, env, form) abort
  if a:env.context ==# 'statement'
    return s:emitln('call '.s:wrap_as_expr(a:file, a:env, a:form))
  endif
  let ary = timl#ary(timl#fnext(a:form))
  let env = s:copy_locals(a:env)
  for i in range(0, len(ary)-1, 2)
    let expr = s:emit(a:file, s:with_context(env, 'expr'), ary[i+1])
    call s:emitstr(a:file, 'let '.s:localfy(timl#symbol#coerce(ary[i])[0]).' = '.expr)
    call s:emitln(a:file, '')
    call s:add_local(env, ary[i])
  endfor
  let body = timl#nnext(a:form)
  if timl#count(body) == 1
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

function! s:one_fn(file, env, form, name, temp) abort
  let env = s:copy_locals(a:env)
  let args = timl#ary(timl#first(a:form))
  let env.params = args
  let body = timl#next(a:form)
  let c = char2nr('a')
  let _ = {}
  let params = []
  for _.arg in args
    if timl#symbol#is(_.arg, '&')
      call add(params, '...')
      call s:add_local(env, args[-1])
      break
    else
      call s:add_local(env, _.arg)
      call add(params, nr2char(c))
    endif
    let c += 1
  endfor
  call s:emitln(a:file, "function ".a:temp."(".join(params, ', ').") abort")
  call s:emitln(a:file, "let temp = {}")
  call s:emitln(a:file, "let locals = copy(self.locals)")
  if len(a:name)
      call s:emitln(a:file, 'let '.s:localfy(a:name).' = self')
  endif
  let c = 0
  for _.arg in args
    if timl#symbol#is(_.arg, '&')
      call s:emitln(a:file, 'let '.s:localfy(args[-1][0]).' = a:000')
      let c = 21 + c
      break
    else
      call s:emitln(a:file, 'let '.s:localfy(_.arg[0]).' = a:'.nr2char(char2nr('a') + c))
    endif
    let c += 1
  endfor
  call s:emitln(a:file, "while 1")
  if timl#count(body) == 1
    call s:emit(a:file, s:with_context(env, 'return'), timl#first(body))
  else
    call s:emit_sf_do(a:file, s:with_context(env, 'return'), timl#cons#create(timl#symbol('do'), body))
  endif
  call s:emitln(a:file, "break")
  call s:emitln(a:file, "endwhile")
  call s:emitln(a:file, "throw 'timl: how did i get here'")
  call s:emitln(a:file, "endfunction")
  return c
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
    call s:one_fn(a:file, env, _.next, name, temp.'.call')
  elseif timl#consp(timl#first(_.next))
    let c = char2nr('a')
    let fns = {}
    while _.next isnot# g:timl#nil
      let fns[s:one_fn(a:file, env, timl#first(_.next), name, temp.'.'.nr2char(c))] = nr2char(c)
      let _.next = timl#next(_.next)
      let c += 1
    endwhile
    call s:emitln(a:file, "function ".temp.".call(...) abort")
    call s:emitln(a:file, "if 0")
    for arity in sort(map(keys(fns), '+v:val'))
      if arity > 20
        call s:emitln(a:file, "elseif a:0 >= ".(21-arity))
      else
        call s:emitln(a:file, "elseif a:0 == ".arity)
      endif
      call s:emitln(a:file, 'return call(self.'.fns[arity]. ', a:000, self)')
    endfor
    call s:emitln(a:file, "else")
    call s:emitln(a:file, "throw 'timl: arity error'")
    call s:emitln(a:file, "endif")
    call s:emitln(a:file, "endfunction")
  endif
  let meta = s:loc_meta(a:form)
  if !empty(meta)
    call s:emitln(a:file, 'let g:timl_functions[join(['.temp.'.call])] = '.timl#compiler#serialize(meta))
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

function! s:colon(file, env, form) abort
  let expr = map(copy(timl#ary(timl#next(a:form))), 's:expr(a:file, a:env, v:val)')
  call s:emitln(a:file, 'execute '.join(expr, ' '))
endfunction

function! s:expr_sf_try(file, env, form) abort
  return s:wrap_as_expr(a:file, a:env, a:form)
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
    if timl#consp(timl#first(_.seq))
      let _.sym = timl#ffirst(_.seq)
      if timl#symbol#is(_.sym, 'catch') || timl#symbol#is(_.sym, 'finally')
        break
      endif
    endif
    call add(body, timl#first(_.seq))
    let _.seq = timl#next(_.seq)
  endwhile
  if timl#count(body) == 1
    call s:emit(a:file, a:env, timl#first(body))
  else
    call s:emit_sf_do(a:file, a:env, timl#cons#create(timl#symbol('do'), body))
  endif
  while _.seq isnot# g:timl#nil
    let _.first = timl#first(_.seq)
    if timl#consp(_.first) && timl#symbol#is(timl#first(_.first), 'catch')
      call s:emitln(a:file, 'catch /'.escape(timl#fnext(_.first), '/').'/')
      let var = timl#first(timl#nnext(_.first))
      let env = s:copy_locals(a:env)
      if timl#symbol#test(var) && var[0] !=# '_'
        call s:add_local(env, var)
        call s:emitln(a:file, 'let '.env.locals[var[0]].' = timl#build_exception(v:exception, v:throwpoint)')
      endif
      call s:emit_sf_do(a:file, env, timl#cons#create(timl#symbol('do'), timl#next(timl#nnext(_.first))))
    elseif timl#consp(_.first) && timl#symbol#is(timl#first(_.first), 'finally')
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
    let var = timl#compiler#resolve_or_throw(target)
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
  elseif timl#consp(target) && timl#symbol#is(timl#first(target), '.')
    let key = substitute(timl#str(timl#first(timl#nnext(target))), '^-', '', '')
    let target2 = timl#symbol#coerce(timl#fnext(target))
    if has_key(a:env.locals, target2[0])
      let var = a:env.locals[target2[0]]
    else
      let var = timl#compiler#resolve_or_throw(target2)
    endif
    let val = s:expr(a:file, a:env, timl#first(rest))
    call s:emitln(a:file, 'let '.var.'['.timl#compiler#serialize(key).'] = '.val)
    return var.'['.timl#compiler#serialize(key).']'
  else
    throw 'timl#compiler: unsupported set! form'
  endif
endfunction

function! s:expr_sf_def(file, env, form) abort
  let rest = timl#next(a:form)
  let var = timl#symbol#coerce(timl#first(rest))
  let assign = 'timl#munge(g:timl#core#_STAR_ns_STAR_.name).'.string('#'.timl#munge(var))
  if timl#next(rest) isnot# g:timl#nil
    let val = s:expr(a:file, a:env, timl#fnext(rest))
    call s:emitln(a:file, 'unlet! g:{'.assign.'}')
    call s:emitln(a:file, 'let g:{'.assign.'} = '.val)
  else
    call s:emitln(a:file, 'if !exists("g:".'.assign.')')
    call s:emitln(a:file, 'let g:{'.assign.'} = g:timl#nil')
    call s:emitln(a:file, 'endif')
  endif
  return 'g:{'.assign.'}'
endfunction

function! s:expr_dot(file, env, form) abort
  let val = s:expr(a:file, a:env, timl#fnext(a:form))
  let key = timl#str(timl#first(timl#nnext(a:form)))
  return val.'['.timl#compiler#serialize(substitute(key, '^-', '', '')).']'
endfunction

function! s:expr_map(file, env, form)
  let kvs = []
  let _ = {'seq': timl#seq(a:form)}
  while _.seq isnot# g:timl#nil
    call extend(kvs, timl#ary(timl#first(_.seq)))
    let _.seq = timl#next(_.seq)
  endwhile
  return 'timl#hash_map(['.join(map(kvs, 's:emit(a:file, s:with_context(a:env, "expr"), v:val)'), ', ').'])'
endfunction

let s:colon = timl#symbol(':')
let s:dot = timl#symbol('.')
function! s:emit(file, env, form) abort
  if timl#consp(a:form)
    let First = timl#first(a:form)
    if First is# s:colon
      call s:colon(a:file, a:env, a:form)
      let expr = 'g:timl#nil'
    elseif First is# s:dot
      let expr = s:expr_dot(a:file, a:env, a:form)
    elseif timl#symbol#test(First)
      let munged = timl#munge(First[0])
      if a:env.context ==# 'expr' && exists('*s:expr_sf_'.munged)
        let expr = s:expr_sf_{munged}(a:file, a:env, a:form)
      elseif exists('*s:emit_sf_'.munged)
        return s:emit_sf_{munged}(a:file, a:env, a:form)
      elseif exists('*s:expr_sf_'.munged)
        let expr = s:expr_sf_{munged}(a:file, a:env, a:form)
      else
        if has_key(a:env.locals, First[0])
          let resolved = a:env.locals[First[0]]
        else
          let resolved = timl#compiler#resolve_or_throw(First)
          let Fn = eval(resolved)
          if timl#type#string(Fn) == 'timl.lang/Function' && timl#truth(get(Fn, 'macro', g:timl#nil))
            let E = timl#call(Fn, [a:form, a:env] + timl#ary(timl#next(a:form)))
            return s:emit(a:file, a:env, E)
          endif
        endif
        let expr = 'timl#call('.resolved.', '.s:expr(a:file, a:env, timl#ary(timl#next(a:form))).')'
      endif
    else
      if timl#consp(First) && timl#symbol#is(timl#first(First), 'function')
        let expr = timl#munge(timl#fnext(First)).'('.s:expr(a:file, a:env, timl#ary(timl#next(a:form)))[1:-2].')'
      else
        let expr = 'timl#call('.s:expr(a:file, a:env, First).', '.s:expr(a:file, a:env, timl#ary(timl#next(a:form))).')'
      endif
    endif
  elseif timl#symbol#test(a:form)
    if has_key(a:env.locals, a:form[0])
      let expr = a:env.locals[a:form[0]]
    else
      let expr = timl#compiler#resolve_or_throw(a:form)
    endif
  elseif type(a:form) == type([]) && a:form isnot# g:timl#nil
    let expr = '['.join(map(copy(a:form), 's:emit(a:file, s:with_context(a:env, "expr"), v:val)'), ', ').']'

  elseif timl#vectorp(a:form)
    let expr = 'timl#vec(['.join(map(copy(timl#ary(a:form)), 's:emit(a:file, s:with_context(a:env, "expr"), v:val)'), ', ').'])'
    let meta = timl#meta(a:form)
    if meta isnot g:timl#nil
      let expr = 'timl#with_meta('.expr.', '.s:expr_map(a:file, a:env, meta).')'
    endif

  elseif timl#setp(a:form)
    let expr = 'timl#set(['.join(map(copy(timl#ary(a:form)), 's:emit(a:file, s:with_context(a:env, "expr"), v:val)'), ', ').'])'
    let meta = timl#meta(a:form)
    if meta isnot g:timl#nil
      let expr = 'timl#with_meta('.expr.', '.s:expr_map(a:file, a:env, meta).')'
    endif

  elseif timl#mapp(a:form)
    let expr = s:expr_map(a:file, a:env, a:form)
    let meta = timl#meta(a:form)
    if meta isnot g:timl#nil
      let expr = 'timl#with_meta('.expr.', '.s:expr_map(a:file, a:env, meta).')'
    endif

  else
    let expr = timl#compiler#serialize(a:form)
  endif
  if a:env.context == 'return'
    call s:emitln(a:file, 'return '.expr)
    return ''
  elseif a:env.context == 'statement'
    if expr =~# '^[[:alnum:]_#]\+('
      call s:emitln(a:file, 'call '.expr)
    elseif expr =~# '^['
      call s:emitln(a:file, 'call timl#identity('.expr.')')
    endif
    return ''
  else
    return expr
  endif
endfunction

function! timl#compiler#emit(form) abort
  let env = {'locals': {}, 'context': 'statement'}
  let file = ['']
  call s:emit(file, env, a:form)
  return join(file, "\n")
endfunction

function! timl#compiler#re(str) abort
  return timl#compiler#emit(timl#reader#read_string(a:str))
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

" Section: Execution

function! timl#compiler#build(x, context, ...) abort
  let file = ['']
  call s:emit(file, {'context': a:context, 'locals': a:0 ? a:1 : {}}, a:x)
  return join(file, "\n") . "\n"
endfunction

function! timl#compiler#eval(x, ...) abort
  let str = timl#compiler#build(a:x, "return", a:0 > 1 ? a:2 : {})
  return s:execute(a:x, str, a:0 > 1 ? a:2 : {})
endfunction

function! s:execute(form, str, ...)
  let s:dict = {}
  let str = "function s:dict.func(locals) abort\n"
        \ . "let locals = a:locals\n"
        \ . "let temp={}\n"
        \ . "while 1\n"
        \ . a:str
        \ . "endwhile\n"
        \ . "endfunction"
  execute str
  let meta = s:loc_meta(a:form)
  if !empty(meta)
    let g:timl_functions[join([s:dict.func])] = meta
  endif
  return s:dict.func(a:0 ? a:1 : {})
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
    let g:timl#core#_STAR_ns_STAR_ = timl#namespace#find(timl#symbol('user'))
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
      let str = timl#compiler#build(_.read, 'return')
      call s:execute(_.read, str)
      call add(strs, "function! s:d.f() abort\nlet locals = {}\nlet temp ={}\n".str."endfunction\n")
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

" Section: Tests

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
TimLCAssert !empty(s:re('(set! (. g:timl_setq key) ["a" "b"])'))
TimLCAssert g:timl_setq ==# {"key": ["a", "b"]}
unlet! g:timl_setq

TimLCAssert s:re("((fn* [n f] (if (<= n 1) f (recur (- n 1) (* f n)))) 5 1)") ==# 120

delcommand TimLCAssert

" vim:set et sw=2:
