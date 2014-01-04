" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_future")
  finish
endif
let g:autoloaded_timl_future = 1

if !exists('s:queue')
  let s:queue = []
endif

function! timl#future#call(fn) abort
  let future = s:type.__call__([a:fn, g:timl#nil, g:timl#nil])
  call add(s:queue, future)
  return future
endfunction

function! timl#future#realize(this) abort
  if a:this.fn isnot# g:timl#nil
    try
      let a:this.val = timl#call(a:this.fn, [])
    catch /^\%(Vim:Interrupt\)\@!.*/
      let a:this.exception = timl#exception#build(v:exception, v:throwpoint)
    endtry
    let a:this.fn = g:timl#nil
  endif
  return a:this
endfunction

function! timl#future#deref(this) abort
  if a:this.fn isnot# g:timl#nil
    call timl#future#realize(a:this)
  endif
  if a:this.exception is# g:timl#nil
    return a:this.val
  endif
  throw substitute(a:this.exception.exception, '^Vim', 'Tim', '')
endfunction

function! timl#future#realized(this) abort
  return a:this.fn is# g:timl#nil ? g:timl#true : g:timl#false
endfunction

function! timl#future#process() abort
  while !empty(s:queue) && !getchar(1)
    call timl#future#realize(remove(s:queue, 0))
  endwhile
endfunction

let s:type = timl#type#core_define('Future', ['fn', 'val', 'exception'], {
      \ 'realized?': 'timl#future#realized',
      \ 'deref': 'timl#future#deref'})

augroup timl_future
  autocmd!
  autocmd CursorHold * call timl#future#process()
augroup END
