" Maintainer: Tim Pope <http://tpo.pe/>

if !exists('g:autoloaded_timl_function')
  let g:autoloaded_timl_function = 1
endif

function! timl#function#invoke(this, ...) abort
  return a:this.apply(a:000)
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

function! timl#function#invoke_self(...) dict
  return timl#call(self, a:000)
endfunction

let s:def = timl#symbol('def')
let s:lets = timl#symbol('let*')
let s:fns = timl#symbol('fn*')
let s:fn = timl#symbol('timl.core/fn')
let s:defn = timl#symbol('timl.core/defn')
let s:setq = timl#symbol('set!')
let s:dot = timl#symbol('.')
let s:form = timl#symbol('&form')
let s:env = timl#symbol('&env')

function! timl#function#fn(form, env, ...)
  return timl#with_meta(timl#cons#from_array([s:fns] + a:000), timl#meta(a:form))
endfunction

function! timl#function#defn(form, env, name, ...)
  return timl#list(s:def, a:name, timl#with_meta(timl#cons#from_array([s:fn, a:name] + a:000), timl#meta(a:form)))
endfunction

function! timl#function#defmacro(form, env, name, params, ...)
  let extra = [s:form, s:env]
  if type(a:params) == type([])
    let body = [extra + a:params] + a:000
  else
    let _ = {}
    let body = []
    for _.list in [a:params] + a:000
      call add(body, timl#cons#create(extra + timl#first(_.list), timl#next(_.list)))
    endfor
  endif
  let fn = timl#symbol#gen('fn')
  return timl#list(s:lets,
        \ [fn, timl#cons#from_array([s:defn, a:name] + body)],
        \ timl#list(s:setq, timl#list(s:dot, fn, timl#symbol('macro')), 1),
        \ fn)
endfunction
