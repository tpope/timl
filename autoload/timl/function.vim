" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_function')
  finish
endif
let g:autoloaded_timl_function = 1

let s:type = timl#type#core_create('Function')

function! timl#function#unimplemented(...) abort
  throw 'timl: unimplemented'
endfunction

function! timl#function#birth(locals, ...) abort
  return timl#type#bless(s:type, {
        \ 'ns': g:timl#core._STAR_ns_STAR_,
        \ 'name': a:0 ? a:1 : g:timl#nil,
        \ 'locals': a:locals,
        \ '__call__': function('timl#function#unimplemented')})
endfunction

function! timl#function#call(this, _) abort
  return a:this.__call__(a:_)
endfunction

function! timl#function#apply(_) abort
  if len(a:_) < 2
    throw 'timl: arity error'
  endif
  let [F; args] = a:_
  let args = args[0:-2] + timl#array#coerce(args[-1])
  return timl#call(F, args)
endfunction

function! timl#function#identity(x) abort
  return a:x
endfunction

function! timl#function#invoke_self(...) dict abort
  return self.__call__(a:000)
endfunction

function! timl#function#hash(fn) abort
  return timl#hash#string(string(a:fn.__call__))
endfunction

let s:def = timl#symbol('def')
let s:let = timl#symbol('timl.core/let')
let s:fns = timl#symbol('fn*')
let s:fn = timl#symbol('timl.core/fn')
let s:defn = timl#symbol('timl.core/defn')
let s:setq = timl#symbol('set!')
let s:dot = timl#symbol('.')
let s:form = timl#symbol('&form')
let s:env = timl#symbol('&env')

function! timl#function#destructure(params, body) abort
  let lets = []
  let params = []
  let _ = {}
  for _.param in timl#array#coerce(a:params)
    if timl#symbol#test(_.param)
      call add(params, _.param)
    else
      call add(params, timl#symbol#gen("p__"))
      call extend(lets, [_.param, params[-1]])
    endif
  endfor
  if empty(lets)
    return timl#cons#create(timl#vector#claim(params), a:body)
  else
    return timl#list(timl#vector#claim(params), timl#cons#create(s:let, timl#cons#create(timl#vector#claim(lets), a:body)))
  endif
endfunction

function! timl#function#fn(form, env, ...) abort
  let _ = {}
  let _.sigs = timl#list#create(a:000)
  if timl#symbol#test(a:000[0])
    let name = a:000[0]
    let _.sigs = timl#coll#next(_.sigs)
  endif
  if timl#vector#test(timl#coll#first(_.sigs))
    let _.sigs = timl#function#destructure(timl#coll#first(_.sigs), timl#coll#next(_.sigs))
  else
    let sigs = []
    while _.sigs isnot# g:timl#nil
      call add(sigs, timl#function#destructure(timl#coll#ffirst(_.sigs), timl#coll#nfirst(_.sigs)))
      let _.sigs = timl#coll#next(_.sigs)
    endwhile
    let _.sigs = timl#list#create(sigs)
  endif
  if exists('name')
    let _.sigs = timl#cons#create(name, _.sigs)
  endif
  return timl#cons#create(s:fns, _.sigs, timl#meta#get(a:form))
endfunction

function! timl#function#defn(form, env, name, ...) abort
  return timl#list#create([s:def, a:name, timl#meta#with(timl#list#create([s:fn, a:name] + a:000), timl#meta#get(a:form))])
endfunction

let s:kmacro = timl#keyword#intern('macro')
function! timl#function#defmacro(form, env, name, params, ...) abort
  let extra = [s:form, s:env]
  if timl#vector#test(a:params)
    let body = [timl#vector#claim(extra + timl#array#coerce(a:params))] + a:000
  else
    let _ = {}
    let body = []
    for _.list in [a:params] + a:000
      call add(body, timl#cons#create(timl#vector#claim(extra + timl#array#coerce(timl#coll#first(_.list))), timl#coll#next(_.list)))
    endfor
  endif
  let name = copy(a:name)
  let name.meta = timl#invoke(g:timl#core.assoc, get(a:name, 'meta', g:timl#nil), s:kmacro, g:timl#true)
  let fn = timl#symbol#gen('fn')
  return timl#list#create([s:defn, name] + body)
endfunction
