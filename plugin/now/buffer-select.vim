if exists('loaded_plugin_now_buffer_select')
  finish
endif
let loaded_plugin_now_buffer_select = 1

let s:cpo_save = &cpo
set cpo&vim

let s:trying_to_delete_buffer = 0

function! s:buffer_leave()
  if s:trying_to_delete_buffer
    return
  endif

  augroup plugin-now-buffer-select
    autocmd!
  augroup end
  augroup! plugin-now-buffer-select

  let _ = s:buffers_window.buffer().delete()
  let s:buffers_window = g:now#vim#window#null
endfunction

command B call <SID>display_buffer_list()

noremap <silent> <Leader>l :B<CR>

let s:previous_window = now#vim#window#null()

let s:buffers_window = now#vim#window#null()

let s:mru = []

function! s:display_buffer_list()
  if !s:buffers_window.closed
    call s:buffers_window.activate()
    return
  endif
  let s:previous_window = now#vim#windows#current()
  keepjumps keepalt wincmd b
  let s:buffers_window = now#vim#windows#add('[Buffers]', { 'type': 'scratch' })

  call s:setup_syntax()

  call s:rebuild_buffer_list()

  augroup plugin-now-buffer-select
    autocmd!
    autocmd BufDelete * silent call <SID>rebuild_buffer_list()
    autocmd BufLeave <buffer> silent call <SID>buffer_leave()
  augroup end

  call s:setup_mappings()

  call cursor(2, 1)
endfunction

function! s:rebuild_buffer_list()
  setlocal modifiable

  let saved_pos = getpos('.')

  silent! 1,$d _
  normal! 0

  let s:mru = now#vim#buffers#to_a('mru', 'listed')
  let max_listed_buffer_nr = 0
  for buffer in s:mru
    if buffer.number > max_listed_buffer_nr
      let max_listed_buffer_nr = buffer.number
    endif
  endfor

  let buffer_number_width = strlen(max_listed_buffer_nr)

  let i = 0
  for buffer in s:mru
    call append(line('$'),
              \ printf("%*d. %s",
              \        buffer_number_width, i,
              \        buffer.displayable_name()))
    let i += 1
  endfor
  1d _

  execute 'resize' line('$')
  setlocal winfixheight

  call setpos('.', saved_pos)

  setlocal nomodifiable
endfunction

function! s:setup_syntax()
  if !has('syntax')
    return
  endif

  syntax match buffersPath /^\s*\d\+\. \zs.*/

"  hi def link buffersPath Directory
endfunction

function! s:setup_mappings()
  let i = 0
  while i < line('$')
    execute 'noremap <buffer> <silent>' i
          \ ':call <SID>select_buffer_nr(' . (i + 1) . ')<CR>'
    let i += 1
  endwhile

  noremap <buffer> <silent> q :q<CR>
  noremap <buffer> <silent> <CR> :call <SID>select_buffer_line()<CR>
  noremap <buffer> <silent> d :call <SID>delete_buffer_line()<CR>
endfunction

function! s:select_buffer_nr(nr)
  call s:select_buffer_lnum(a:nr)
endfunction

function! s:select_buffer_line()
  call s:select_buffer_lnum(line('.'))
endfunction

function! s:select_buffer_lnum(lnum)
  call s:select_buffer(s:get_buffer_from_line(a:lnum))
endfunction

function! s:get_buffer_from_line(lnum)
  return s:mru[a:lnum - 1]
endfunction

function! s:select_buffer(buffer)
  " TODO: This probably “can’t” happen…nonetheless it may be worth keeping
  " around.
  if !a:buffer.exists()
    echoerr printf("E86: Buffer %d does not exist", a:buffer.number)
    call s:rebuild_buffer_list()
    return
  endif
  silent! close!
  if s:previous_window.number > now#vim#windows#count()
    call a:buffer.split()
  else
    call s:previous_window.activate()
    call a:buffer.activate()
  endif
endfunction

function! s:delete_buffer_line()
  call s:delete_buffer(s:get_buffer_from_line(line('.')))
endfunction

function! s:delete_buffer(buffer)
  try
    " TODO: What a mess, but there are a bunch of edge cases here and the
    " problem is that I really don’t like it that all windows showing a buffer
    " disappear when the buffer is deleted.  This solution doesn’t work when
    " all windows are showing the given buffer and there is more than one
    " window.
    let s:trying_to_delete_buffer = len(s:mru) > 1
    if now#vim#windows#count() == 2 && a:buffer.window().number != -1
      let saved_window = now#vim#windows#current()
      let _ = a:buffer.window().activate()
      if len(s:mru) == 1
        new
      else
        let alternate = now#vim#buffers#alternate()
        if !alternate.exists()
          bnext
        elseif !alternate.listed()
          " TODO: Should we use s:mru here instead?
          let idx = g:now#vim#buffers#mru.index(a:buffer.number)
          let idx = idx == g:now#vim#buffers#mru.count() ? 0 : idx + 1
          let _ = g:now#vim#buffers#mru.item(idx).activate()
        else
          call alternate.activate()
        endif
      end
      call saved_window.activate()
    endif
    call a:buffer.delete()
    let s:trying_to_delete_buffer = 0
  catch
    echohl Error | echo v:exception | echohl None
  endtry
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
