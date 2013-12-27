" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lazy_seq")
  finish
endif
let g:autoloaded_timl_lazy_seq = 1

function! timl#lazy_seq#create(fn)
  return timl#type#bless('timl.lang/LazySeq', {'fn': a:fn, 'meta': g:timl#nil})
endfunction

function! timl#lazy_seq#seq(lseq) abort
  if !has_key(a:lseq, 'seq')
    let _ = {'seq': timl#invoke(a:lseq.fn)}
    while !timl#type#canp(_.seq, g:timl#core#more)
      let _.seq = timl#invoke(g:timl#core#seq, _.seq)
    endwhile
    let a:lseq.seq = timl#invoke(g:timl#core#seq, _.seq)
    let a:lseq.fn = g:timl#nil
  endif
  return a:lseq.seq
endfunction

function! timl#lazy_seq#realized(lseq) abort
  return a:lseq.fn is# g:timl#nil ? g:timl#true : g:timl#false
endfunction
