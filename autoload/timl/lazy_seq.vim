" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lazy_seq")
  finish
endif
let g:autoloaded_timl_lazy_seq = 1

function! timl#lazy_seq#create(fn)
  return timl#type#bless('timl.lang/LazySeq', {'fn': a:fn})
endfunction

function! timl#lazy_seq#seq(lseq) abort
  if !has_key(a:lseq, 'seq')
    let _ = {'seq': timl#call(a:lseq.fn, [])}
    while !timl#type#canp(_.seq, g:timl#core#more)
      let _.seq = timl#type#dispatch(g:timl#core#seq, _.seq)
    endwhile
    let a:lseq.seq = timl#type#dispatch(g:timl#core#seq, _.seq)
    unlet a:lseq.fn
  endif
  return a:lseq.seq
endfunction

function! timl#lazy_seq#count(lseq) abort
  return timl#type#dispatch(g:timl#core#count, timl#lazy_seq#seq(a:lseq))
endfunction

function! timl#lazy_seq#realized(lseq) abort
  return has_key(a:lseq, 'fn') ? g:timl#false : g:timl#true
endfunction
