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
      \ 'recur': 1,
      \ 'def': 1,
      \ 'deftype*': 1,
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

function! timl#compiler#specialp(sym) abort
  return has_key(s:specials, timl#string#coerce(a:sym))
endfunction

function! timl#compiler#resolve(sym) abort
  if a:sym[0] =~# '^\w:'
    return {'location': timl#var#munge(a:sym[0])}
  elseif a:sym[0][0] ==# '$'
    return {'location': "(exists('".a:sym[0]."') ? ".a:sym[0]." : g:timl#nil)"}
  elseif (a:sym[0] =~# '^&\w' && exists(a:sym[0]))
    return {'location': a:sym[0]}
  elseif a:sym[0] =~# '\.[^/]\+$'
    return {'location': 'g:'.timl#namespace#munge(a:sym[0])}
  endif
  let var = timl#namespace#maybe_resolve(g:timl#core._STAR_ns_STAR_, a:sym)
  if var isnot# g:timl#nil
    return var
  endif
  throw "timl#compiler: could not resolve ".timl#string#coerce(a:sym)
endfunction

" Section: Macroexpand

let s:kmacro = timl#keyword#intern('macro')
function! timl#compiler#macroexpand_1(form) abort
  if timl#coll#seqp(a:form) && timl#symbol#test(timl#coll#first(a:form)) && !timl#compiler#specialp(timl#coll#first(a:form))
    let var = timl#namespace#maybe_resolve(g:timl#core._STAR_ns_STAR_, timl#coll#first(a:form))
    if var isnot# g:timl#nil && timl#truth(timl#coll#get(var.meta, s:kmacro))
      return timl#call(timl#var#get(var), [a:form, {}] + timl#array#coerce(timl#coll#next(a:form)))
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

function! timl#compiler#serialize(x) abort
  " TODO: guard against recursion
  if timl#keyword#test(a:x)
    return 'timl#keyword#intern('.timl#compiler#serialize(a:x[0]).')'

  elseif timl#symbol#test(a:x)
    if a:x.meta isnot# g:timl#nil
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

  elseif timl#list#emptyp(a:x)
    if a:x.meta isnot# g:timl#nil
      return 'timl#meta#with(g:timl#empty_list, '.timl#compiler#serialize(a:x.meta).')'
    else
      return 'g:timl#empty_list'
    endif

  elseif type(a:x) == type([])
    return '['.join(map(copy(a:x), 'timl#compiler#serialize(v:val)'), ', ').']'

  elseif timl#vector#test(a:x)
    return 'timl#vector#claim(['.join(map(timl#array#coerce(a:x), 'timl#compiler#serialize(v:val)'), ', ').'])'

  elseif timl#map#test(a:x) && timl#type#string(a:x) !=# 'vim/Dictionary'
    let _ = {}
    let keyvals = []
    let _.seq = timl#coll#seq(a:x)
    while _.seq isnot# g:timl#nil
      call extend(keyvals, timl#array#coerce(timl#coll#first(_.seq)))
      let _.seq = timl#coll#next(_.seq)
    endwhile
    return 'timl#map#create('.timl#compiler#serialize(keyvals).')'

  elseif timl#set#test(a:x)
    let _ = {}
    let keyvals = []
    let _.seq = timl#coll#seq(a:x)
    while _.seq isnot# g:timl#nil
      call add(keyvals, timl#coll#first(_.seq))
      let _.seq = timl#coll#next(_.seq)
    endwhile
    return 'timl#set#coerce('.timl#compiler#serialize(keyvals).')'

  elseif timl#type#string(a:x) ==# 'timl.lang/Cons'
    return 'timl#cons#create('
          \ . timl#compiler#serialize(a:x.car).','
          \ . timl#compiler#serialize(a:x.cdr).','
          \ . timl#compiler#serialize(a:x.meta).')'

  elseif timl#type#string(a:x) ==# 'timl.lang/Type'
    return 'timl#type#find('.timl#compiler#serialize(timl#symbol#intern(a:x.str)).')'

  elseif timl#var#test(a:x)
    return 'timl#var#find('.timl#compiler#serialize(timl#symbol#intern(a:x.str)).')'

  elseif type(a:x) == type('')
    return '"'.substitute(a:x, "[\001-\037\"\\\\]", '\=get(s:escapes, submatch(0), printf("\\%03o", char2nr(submatch(0))))', 'g').'"'
  elseif type(a:x) == 5 && string(a:x) =~# 'n'
    if string(a:x) ==# 'inf'
      return '(1/0.0)'
    elseif string(a:x) ==# '-inf'
      return '(-1/0.0)'
    else
      return '(0/0.0)'
    endif
  elseif type(a:x) != type({})
    return string(a:x)

  elseif timl#type#objectp(a:x)
    return 'timl#type#bless('.timl#compiler#serialize(a:x.__type__) . ', ' . timl#compiler#serialize(filter(copy(a:x), 'v:key !~# "^__.*__$"')).')'

  else
    let acc = []
    for [k, V] in items(a:x)
      call add(acc, timl#compiler#serialize(k) . ': ' . timl#compiler#serialize(V))
      unlet! V
    endfor
    return '{' . join(acc, ', ') . '}'

  endif
endfunction

" Section: Emission

function! s:emitln(file, str) abort
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

function! s:let_tmp(file, env, clue, str) abort
  let a:env.temp[a:clue] = get(a:env.temp, a:clue, 0) + 1
  let temp = a:clue . a:env.temp[a:clue]
  call s:emitln(a:file, 'let '.temp.' = '.a:str)
  return temp
endfunction

function! s:wrap_as_expr(file, env, form) abort
  let env = s:with_context(a:env, 'return')
  if has_key(env, 'params')
    call remove(env, 'params')
  endif
  let temp = s:let_tmp(a:file, env, 'thunk', '{"locals": copy(locals)}')
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

let s:k_as = timl#keyword#intern('as')
let s:k_or = timl#keyword#intern('or')

function! s:assign(file, env, key, val) abort
  let _ = {}
  if timl#symbol#test(a:key)
    call s:emitln(a:file, 'let '.s:localfy(a:key[0]).' = '.a:val)
    return s:add_local(a:env, a:key)
  elseif timl#vector#test(a:key)
    let coll = s:let_tmp(a:file, a:env, 'coll', a:val)
    let array = s:let_tmp(a:file, a:env, 'array', 'timl#array#coerce('.coll.')')
    let _.seq = timl#coll#seq(a:key)
    let i = 0
    while _.seq isnot g:timl#nil
      let _.elem = timl#coll#first(_.seq)
      let _.seq = timl#coll#next(_.seq)
      if timl#symbol#is(_.elem, '&')
        call s:assign(a:file, a:env, timl#coll#first(_.seq), 'timl#array#seq('.array.', '.i.')')
        let _.seq = timl#coll#next(_.seq)
      elseif _.elem is# s:k_as
        call s:assign(a:file, a:env, timl#coll#first(_.seq), coll)
        let _.seq = timl#coll#next(_.seq)
      else
        call s:assign(a:file, a:env, _.elem, 'get('.array.', '.i.', g:timl#nil)')
      endif
      let i += 1
    endwhile

  elseif timl#map#test(a:key)
    let as = timl#coll#get(a:key, s:k_as, a:key)
    if as isnot# a:key
      let coll = s:localfy(timl#symbol#cast(as).name)
      call s:emitln(a:file, 'let '.coll.' = '.a:val)
      call s:add_local(a:env, as)
    else
      let coll = s:let_tmp(a:file, a:env, 'coll', a:val)
    endif
    let or = timl#coll#get(a:key, s:k_or)

    let map = s:let_tmp(a:file, a:env, 'map', 'timl#map#soft_coerce('.coll.')')
    let _.seq = timl#coll#seq(a:key)
    while _.seq isnot g:timl#nil
      let _.pair = timl#coll#first(_.seq)
      let _.var = timl#coll#first(_.pair)
      if _.var isnot# s:k_as && _.var isnot# s:k_or
        if timl#coll#get(or, _.var, or) isnot# or
          call s:assign(a:file, a:env, timl#coll#first(_.pair), 'timl#coll#get('.map
                \ . ', ' . s:expr(a:file, a:env, timl#coll#fnext(_.pair))
                \ . ', ' . s:expr(a:file, a:env, timl#coll#get(or, _.var)).')')
        else
          call s:assign(a:file, a:env, _.var, 'timl#coll#get('.map.', '.s:expr(a:file, a:env, timl#coll#fnext(_.pair)).')')
        endif
      endif
      let _.seq = timl#coll#next(_.seq)
    endwhile

  elseif timl#keyword#test(a:key)
    throw 'timl: invalid binding :'.a:key[0]
  else
    throw 'timl: invalid binding type '.timl#type#string(a:key)
  endif
endfunction

function! s:emit_sf_let_STAR_(file, env, form) abort
  if a:env.context ==# 'statement'
    return s:emitln(a:file, 'call '.s:wrap_as_expr(a:file, a:env, a:form))
  endif
  let ary = timl#array#coerce(timl#coll#fnext(a:form))
  let env = s:copy_locals(a:env)
  for i in range(0, len(ary)-1, 2)
    call s:assign(a:file, env, ary[i], s:expr(a:file, env, ary[i+1]))
  endfor
  let body = timl#coll#nnext(a:form)
  if timl#coll#count(body) == 1
    return s:emit(a:file, env, timl#coll#first(body))
  else
    return s:emit_sf_do(a:file, env, timl#cons#create(timl#symbol('do'), body))
  endif
endfunction

function! s:expr_sf_do(file, env, form) abort
  return s:wrap_as_expr(a:file, a:env, a:form)
endfunction

function! s:emit_sf_do(file, env, form) abort
  let ary = timl#array#coerce(timl#coll#next(a:form))
  if empty(ary)
    return s:emit(a:file, a:env, g:timl#nil)
  endif
  for i in range(len(ary) - 1)
    call s:emit(a:file, s:with_context(a:env, 'statement'), ary[i])
  endfor
  call s:emit(a:file, a:env, ary[-1])
endfunction

function! s:expr_sf_if(file, env, form) abort
  let ary = timl#array#coerce(timl#coll#next(a:form))
  return 'timl#truth('.s:emit(a:file, a:env, ary[0]) . ')'
        \ . ' ? ' . s:emit(a:file, a:env, get(ary, 1, g:timl#nil))
        \ . ' : ' . s:emit(a:file, a:env, get(ary, 2, g:timl#nil))
endfunction

function! s:emit_sf_if(file, env, form) abort
  let ary = timl#array#coerce(timl#coll#next(a:form))
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
  return timl#compiler#serialize(timl#coll#fnext(a:form))
endfunction

function! s:expr_sf_function(file, env, form) abort
  return "function(".timl#compiler#serialize(timl#string#coerce(timl#coll#fnext(a:form))).")"
endfunction

function! s:expr_sf_var(file, env, form) abort
  let sym = timl#symbol#cast(timl#coll#fnext(a:form))
  let var = timl#namespace#maybe_resolve(g:timl#core._STAR_ns_STAR_, sym)
  if var isnot# g:timl#nil
    return timl#compiler#serialize(var)
  endif
  throw "timl#compiler: could not resolve ".timl#string#coerce(sym)
endfunction

function! s:one_fn(file, env, form, name, temp, catch_errors) abort
  let env = s:copy_locals(a:env)
  let args = timl#array#coerce(timl#coll#first(a:form))
  let env.params = args
  let body = timl#coll#next(a:form)
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
  call s:emitln(a:file, "function! ".a:temp."(_) abort")
  call s:emitln(a:file, "let locals = copy(self.locals)")
  if len(a:name)
    call s:emitln(a:file, 'let '.s:localfy(a:name).' = self')
  endif
  if a:catch_errors && !empty(positional)
    call s:emitln(a:file, 'try')
  endif
  if !empty(positional)
    call s:emitln(a:file, "let [".join(positional, ', ').(exists('rest') ? '; rest' : '')."] = a:_")
    if exists('rest')
      call s:emitln(a:file, "let ".rest." = timl#array#seq(rest)")
    endif
  elseif exists('rest')
    call s:emitln(a:file, "let ".rest." = timl#array#seq(a:_)")
  endif
  if a:catch_errors && !empty(positional)
    call s:emitln(a:file, 'catch /^Vim(let):E68[78]:/')
    call s:emitln(a:file, "throw 'timl: arity error'")
    call s:emitln(a:file, 'endtry')
  endif
  let c = 0
  call s:emitln(a:file, "while 1")
  if timl#coll#count(body) == 1
    call s:emit(a:file, s:with_context(env, 'return'), timl#coll#first(body))
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
  let _.next = timl#coll#next(a:form)
  if timl#symbol#test(timl#coll#first(_.next))
    let name = timl#coll#first(_.next)[0]
    let env.locals[name] = s:localfy(name)
    let _.next = timl#coll#next(_.next)
  else
    let name = ''
  endif
  let temp = s:let_tmp(a:file, a:env, 'fn', 'timl#function#birth(copy(locals)' . (empty(name) ? '' : ', timl#symbol#intern('.string(name).')').')')
  if timl#vector#test(timl#coll#first(_.next))
    call s:one_fn(a:file, env, _.next, name, temp.".__call__", 1)
  elseif timl#coll#sequentialp(timl#coll#first(_.next))
    let c = char2nr('a')
    let fns = {}
    while _.next isnot# g:timl#nil
      let fns[s:one_fn(a:file, env, timl#coll#first(_.next), name, temp.'.'.nr2char(c), 0)] = nr2char(c)
      let _.next = timl#coll#next(_.next)
      let c += 1
    endwhile
    call s:emitln(a:file, "function! ".temp.".__call__(_) abort")
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
    call s:emitln(a:file, 'let g:timl_functions[join(['.temp.".__call__])] = ".timl#compiler#serialize(meta))
  endif
  return temp
endfunction

function! s:emit_sf_recur(file, env, form) abort
  if a:env.context !=# 'return' || !has_key(a:env, 'params')
    throw 'timl#compiler: recur outside of tail position'
  endif
  let bindings = map(copy(filter(copy(a:env.params), 'v:val[0] !=# "&"')), 'a:env.locals[v:val[0]]')
  call s:emitln(a:file, 'let ['.join(bindings, ', ').'] = ['.s:expr_args(a:file, a:env, timl#coll#next(a:form)).']')
  call s:emitln(a:file, 'continue')
endfunction

function! s:expr_sf_execute(file, env, form) abort
  return s:wrap_as_expr(a:file, a:env, a:form)
endfunction

function! s:emit_sf_execute(file, env, form) abort
  let expr = map(copy(timl#array#coerce(timl#coll#next(a:form))), 's:expr(a:file, a:env, v:val)')
  call s:emitln(a:file, 'execute '.join(expr, ' '))
  return s:emit(a:file, a:env, g:timl#nil)
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
  let _.seq = timl#coll#next(a:form)
  let body = []
  while _.seq isnot# g:timl#nil
    if timl#coll#seqp(timl#coll#first(_.seq))
      let _.sym = timl#coll#ffirst(_.seq)
      if timl#symbol#is(_.sym, 'catch') || timl#symbol#is(_.sym, 'finally')
        break
      endif
    endif
    call add(body, timl#coll#first(_.seq))
    let _.seq = timl#coll#next(_.seq)
  endwhile
  if timl#coll#count(body) == 1
    call s:emit(a:file, a:env, timl#coll#first(body))
  else
    call s:emit_sf_do(a:file, a:env, timl#cons#create(timl#symbol('do'), body))
  endif
  while _.seq isnot# g:timl#nil
    let _.first = timl#coll#first(_.seq)
    if timl#coll#seqp(_.first) && timl#symbol#is(timl#coll#first(_.first), 'catch')
      call s:emitln(a:file, 'catch /'.escape(timl#coll#fnext(_.first), '/').'/')
      let var = timl#coll#first(timl#coll#nnext(_.first))
      let env = s:copy_locals(a:env)
      if timl#symbol#test(var) && var[0] !=# '_'
        call s:add_local(env, var)
        call s:emitln(a:file, 'let '.env.locals[var[0]].' = timl#exception#build(v:exception, v:throwpoint)')
      endif
      call s:emit_sf_do(a:file, env, timl#cons#create(timl#symbol('do'), timl#coll#next(timl#coll#nnext(_.first))))
    elseif timl#coll#seqp(_.first) && timl#symbol#is(timl#coll#first(_.first), 'finally')
      call s:emitln(a:file, 'finally')
      call s:emit_sf_do(a:file, s:with_context(a:env, 'statement'), timl#cons#create(timl#symbol('do'), timl#coll#next(_.first)))
    else
      throw 'timl#compiler: invalid form after catch or finally try'
    endif
    let _.seq = timl#coll#next(_.seq)
  endwhile
  call s:emitln(a:file, 'endtry')
endfunction

function! s:expr_sf_throw(file, env, form) abort
  return s:wrap_as_expr(a:file, a:env, a:form)
endfunction

function! s:emit_sf_throw(file, env, form) abort
  call s:emitln(a:file, 'throw '.s:expr(a:file, a:env, timl#coll#fnext(a:form)))
endfunction

function! s:expr_sf_set_BANG_(file, env, form) abort
  let target = timl#coll#fnext(a:form)
  let rest = timl#coll#nnext(a:form)
  if timl#symbol#test(target)
    let var = timl#compiler#resolve(target).location
    if rest isnot# g:timl#nil
      let val = s:expr(a:file, a:env, timl#coll#first(rest))
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
  elseif timl#coll#seqp(target) && timl#symbol#is(timl#coll#first(target), '.')
    let key = substitute(timl#string#coerce(timl#coll#first(timl#coll#nnext(target))), '^-', '', '')
    let target2 = timl#symbol#cast(timl#coll#fnext(target))
    if has_key(a:env.locals, target2[0])
      let var = a:env.locals[target2[0]]
    else
      let var = timl#compiler#resolve(target2).location
    endif
    let val = s:expr(a:file, a:env, timl#coll#first(rest))
    call s:emitln(a:file, 'let '.var.'['.timl#compiler#serialize(key).'] = '.val)
    return var.'['.timl#compiler#serialize(key).']'
  else
    throw 'timl#compiler: unsupported set! form'
  endif
endfunction

let s:kline = timl#keyword#intern('line')
let s:kfile = timl#keyword#intern('file')
function! s:expr_sf_def(file, env, form) abort
  let rest = timl#coll#next(a:form)
  let var = timl#symbol#cast(timl#coll#first(rest))
  if has_key(a:env, 'file')
    let var = timl#meta#vary(var, g:timl#core.assoc, s:kline, a:env.line, s:kfile, a:env.file)
  endif
  if timl#coll#next(rest) isnot# g:timl#nil
    let val = s:expr(a:file, a:env, timl#coll#fnext(rest))
    return 'timl#namespace#intern(g:timl#core._STAR_ns_STAR_, '.timl#compiler#serialize(var).', '.val.')'
  else
    return 'timl#namespace#intern(g:timl#core._STAR_ns_STAR_, '.timl#compiler#serialize(var).')'
  endif
endfunction

function! s:expr_sf_deftype_STAR_(file, env, form) abort
  let rest = timl#coll#next(a:form)
  let var = timl#symbol#cast(timl#coll#first(rest))
  let slots = timl#array#coerce(timl#coll#fnext(rest))
  if has_key(a:env, 'file')
    let var = timl#meta#vary(var, g:timl#core.assoc, s:kline, a:env.line, s:kfile, a:env.file)
  endif
  return 'timl#type#define(g:timl#core._STAR_ns_STAR_, '.timl#compiler#serialize(var).', '.timl#compiler#serialize(slots).')'
endfunction

function! s:expr_dot(file, env, form) abort
  let val = s:expr(a:file, a:env, timl#coll#fnext(a:form))
  let key = timl#coll#first(timl#coll#nnext(a:form))
  if timl#coll#sequentialp(key)
    return val.'['.timl#compiler#serialize(timl#string#coerce(timl#coll#first(key))).']('.s:expr_args(a:file, a:env, timl#coll#next(key)).')'
  else
    return val.'['.timl#compiler#serialize(timl#string#coerce(key)).']'
  endif
endfunction

function! s:expr_map(file, env, form) abort
  let kvs = []
  let _ = {'seq': timl#coll#seq(a:form)}
  while _.seq isnot# g:timl#nil
    call extend(kvs, timl#array#coerce(timl#coll#first(_.seq)))
    let _.seq = timl#coll#next(_.seq)
  endwhile
  return 'timl#map#create(['.join(map(kvs, 's:emit(a:file, s:with_context(a:env, "expr"), v:val)'), ', ').'])'
endfunction

function! s:expr_args(file, env, form) abort
  return join(map(copy(timl#array#coerce(a:form)), 's:emit(a:file, s:with_context(a:env, "expr"), v:val)'), ', ')
endfunction

function! s:emit(file, env, form) abort
  let env = a:env
  try
    if timl#coll#seqp(a:form)
      if get(a:form, 'meta', g:timl#nil) isnot# g:timl#nil && has_key(a:form.meta, 'line')
        let env = copy(env)
        let env.line = a:form.meta.line
      endif
      let First = timl#coll#first(a:form)
      if timl#symbol#is(First, '.')
        let expr = s:expr_dot(a:file, env, a:form)
      elseif timl#symbol#test(First)
        let munged = timl#var#munge(First[0])
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
            if get(var, 'meta', g:timl#nil) isnot# g:timl#nil && timl#truth(timl#coll#get(var.meta, s:kmacro))
              let E = timl#call(timl#var#get(var), [a:form, env] + timl#array#coerce(timl#coll#next(a:form)))
              return s:emit(a:file, env, E)
            endif
            let resolved = var.location
          endif
          let args = s:expr_args(a:file, env, timl#coll#next(a:form))
          let expr = resolved.'.__call__(['.args.'])'
        endif
      elseif First is# g:timl#nil && timl#coll#count(a:form) ==# 0
        let expr = timl#compiler#serialize(a:form)
      else
        let args = s:expr_args(a:file, env, timl#coll#next(a:form))
        if timl#coll#seqp(First) && timl#symbol#is(timl#coll#first(First), 'function')
          let expr = timl#var#munge(timl#coll#fnext(First)).'('.args.')'
        elseif type(First) == type(function('tr'))
          let expr = join([First]).'('.args.')'
        else
          let expr = s:expr(a:file, env, First).'.__call__(['.args.'])'
        endif
      endif
    elseif timl#symbol#test(a:form)
      if has_key(env.locals, a:form[0])
        let expr = env.locals[a:form[0]]
      else
        let expr = timl#compiler#resolve(a:form).location
      endif
    elseif type(a:form) == type([]) && a:form isnot# g:timl#nil
      let expr = 'timl#function#identity(['.s:expr_args(a:file, env, a:form).'])'

    elseif timl#vector#test(a:form)
      let expr = 'timl#vector#claim(['.join(map(copy(timl#array#coerce(a:form)), 's:emit(a:file, s:with_context(env, "expr"), v:val)'), ', ').'])'

    elseif timl#set#test(a:form)
      let expr = 'timl#set#coerce(['.join(map(copy(timl#array#coerce(a:form)), 's:emit(a:file, s:with_context(env, "expr"), v:val)'), ', ').'])'

    elseif timl#map#test(a:form)
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
      if expr !~# '^["'']' && expr =~# '('
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

function! timl#compiler#location_meta(file, form) abort
  let meta = timl#meta#get(a:form)
  if type(meta) == type({}) && has_key(meta, 'line') && a:file isnot# 'NO_SOURCE_PATH'
    return {'file': a:file, 'line': meta.line}
  else
    return {}
  endif
endfunction

function! s:function_gc() abort
  for fn in keys(g:timl_functions)
    if !timl#funcref#exists(fn)
      call remove(g:timl_functions, fn)
    endif
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
  call s:emit(file, {'file': filename, 'line': 1, 'context': 'return', 'locals': {}, 'temp': {}}, a:x)
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
