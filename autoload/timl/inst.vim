" Maintainer: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_timl_inst')
  finish
endif
let g:autoloaded_timl_inst = 1

function! timl#inst#sleep(msec) abort
  execute 'sleep' a:msec.'m'
  return g:timl#nil
endfunction

function! timl#inst#create(...) abort
  if !a:0
    return timl#inst#now()
  elseif type(a:1) == type('')
    return timl#inst#parse(a:1)
  elseif type(a:1) == type(0)
    return timl#inst#from_ts(a:1)
  elseif type(a:1) == 5
    return timl#inst#from_ts(float2nr(a:1), float2nr(1000000*abs(a:1-trunc(a:1))))
  elseif type(a:1) == type({}) && get(a:1, '__type__') == s:type
    return a:1
  endif
  throw "timl: can't create Instant from ".timl#type#string(a:1)
endfunction

" In Vim, -4 / 3 == -1.  Let's return -2 instead.
function! s:div(a,b) abort
  if a:a < 0 && a:b > 0
    return (a:a-a:b+1)/a:b
  elseif a:a > 0 && a:b < 0
    return (a:a-a:b-1)/a:b
  else
    return a:a / a:b
  endif
endfunction

function! timl#inst#jd(year, mon, day) abort
  let y = a:year + 4800 - (a:mon <= 2)
  let m = a:mon + (a:mon <= 2 ? 9 : -3)
  let jul = a:day + (153*m+2)/5 + s:div(1461*y,4) - 32083
  return jul - s:div(y,100) + s:div(y,400) + 38
endfunction

let s:jdepoch = timl#inst#jd(1970, 1, 1)
function! timl#inst#ts(year, mon, day, hour, min, sec) abort
  return (timl#inst#jd(a:year, a:mon, a:day) - s:jdepoch) * 86400 + a:hour * 3600 + a:min * 60 + a:sec
endfunction

function! timl#inst#parse(str) abort
  let str = timl#string#coerce(a:str)
  let results = matchlist(str, '\c\v(\d{4})-(\d\d)-(\d\d)t(\d\d):(\d\d):(\d\d)%(\.(\d+))=%(z|([+-]\d\d):(\d\d))$')
  if !empty(results)
    call remove(results, 0)
    let results[6] = results[6][0:5] . repeat('0', 6-len(results[6]))
    call map(results, 'str2nr(v:val)')
    let t = {}
    let [t.year, t.mon, t.day, t.hour, t.min, t.sec, t.usec] = results[0:6]
    let t.offset = results[7] * 60 + results[8]
    let t.unix = timl#inst#ts(t.year, t.mon, t.day, t.hour, t.min-t.offset, t.sec)
    return timl#type#bless(s:type, t)
  endif
  throw "timl: invalid date string ".str
endfunction

function! timl#inst#from_ts(sec, ...) abort
  let t = {'unix': a:sec, 'usec': a:0 ? a:1 : 0}
  let components = map(split(strftime("%Y %m %d %H %M %S", t.unix), ' '), 'str2nr(v:val)')
  let t.offset = (call('timl#inst#ts', components) - t.unix)/60
  let [t.year, t.mon, t.day, t.hour, t.min, t.sec] = components
  return timl#type#bless(s:type, t)
endfunction

function! timl#inst#now() abort
  if has('unix')
    return call('timl#inst#from_ts', reltime())
  elseif has('ruby')
    ruby VIM.command('return timl#inst#from_ts(%s, str2nr("%s"[0:5]))' % Time.now.to_f.to_s.split('.'))
  else
    return timl#inst#from_ts(localtime())
  endif
endfunction

function! timl#inst#to_string(t) abort
  let min_offset = a:t.offset % 60
  return printf('%04d-%02d-%02dT%02d:%02d:%02d.%06d%+03d:%02d', a:t.year, a:t.mon, a:t.day, a:t.hour, a:t.min, a:t.sec, a:t.usec, a:t.offset/60, (a:t.offset < 0 ? -1 : 1) * a:t.offset % 60)
endfunction

let s:type = timl#type#core_define('Instant', ['year', 'mon', 'day', 'hour', 'min', 'sec', 'offset', 'unix'], {
      \ 'to-string': 'timl#inst#to_string'})
