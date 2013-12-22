" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_function')
  finish
endif
let g:autoloaded_timl_function = 1

function! timl#function#call(this, _) abort
  return a:this.apply(a:_)
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

let s:kmacro = timl#keyword#intern('macro')
function! timl#function#defmacro(form, env, name, params, ...)
  let extra = [s:form, s:env]
  if timl#vectorp(a:params)
    let body = [timl#vector#claim(extra + timl#ary(a:params))] + a:000
  else
    let _ = {}
    let body = []
    for _.list in [a:params] + a:000
      call add(body, timl#cons#create(timl#vector#claim(extra + timl#ary(timl#first(_.list))), timl#next(_.list)))
    endfor
  endif
  let name = copy(a:name)
  let name.meta = timl#invoke(g:timl#core#assoc, get(a:name, 'meta', g:timl#nil), s:kmacro, g:timl#true)
  let fn = timl#symbol#gen('fn')
  return timl#cons#from_array([s:defn, name] + body)
endfunction
