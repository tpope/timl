" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lazy_seq")
  finish
endif
let g:autoloaded_timl_lazy_seq = 1

let s:placeholder = {}
function! timl#lazy_seq#create(fn) abort
  return timl#type#bless(s:type, {'fn': a:fn, 'val': g:timl#nil, 'seq': s:placeholder, 'meta': g:timl#nil})
endfunction

function! timl#lazy_seq#with_meta(this, meta) abort
  return timl#type#bless(s:type, {'fn': g:timl#nil, 'val': s:val(a:this), 'seq': a:this.seq, 'meta': a:meta})
endfunction

function! s:val(lseq) abort
  if a:lseq.fn isnot# g:timl#nil
    let a:lseq.val = timl#call(a:lseq.fn, [])
    let a:lseq.fn = g:timl#nil
  endif
  return a:lseq.val
endfunction

function! timl#lazy_seq#seq(lseq) abort
  if a:lseq.seq is# s:placeholder
    let _ = {'seq': a:lseq}
    let i = 0
    while timl#type#string(_.seq) ==# s:type.str
      let i += 1
      let _.seq = s:val(_.seq)
    endwhile
    let a:lseq.seq = timl#invoke(g:timl#core.seq, _.seq)
  endif
  return a:lseq.seq
endfunction

function! timl#lazy_seq#car(lseq) abort
  return timl#coll#first(timl#lazy_seq#seq(a:lseq))
endfunction

function! timl#lazy_seq#cdr(lseq) abort
  return timl#coll#rest(timl#lazy_seq#seq(a:lseq))
endfunction

function! timl#lazy_seq#realized(lseq) abort
  return a:lseq.fn is# g:timl#nil ? g:timl#true : g:timl#false
endfunction

let s:type = timl#type#core_define('LazySeq', ['fn', 'val', 'seq', 'meta'], {
      \ 'get-meta': 'timl#meta#from_attribute',
      \ 'with-meta': 'timl#lazy_seq#with_meta',
      \ 'seq': 'timl#lazy_seq#seq',
      \ 'car': 'timl#lazy_seq#car',
      \ 'cdr': 'timl#lazy_seq#cdr',
      \ 'equiv': 'timl#equality#seq',
      \ 'realized?': 'timl#lazy_seq#realized',
      \ 'conj': 'timl#cons#conj',
      \ 'empty': 'timl#list#empty'})
