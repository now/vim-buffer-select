" Vim plugin file
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-07-23

if exists('loaded_plugin_now_buffer_select')
  finish
endif

let loaded_plugin_now_buffer_select = 1

let s:cpo_save = &cpo
set cpo&vim

let s:mru = []

augroup buffer-select
  autocmd VimEnter  * silent call <SID>mru_build()
  autocmd BufEnter  * silent call <SID>mru_push()
  autocmd BufDelete * silent call <SID>mru_pop()
  autocmd BufLeave \[Buffers\] silent! close!
augroup end

function s:mru_build()
  let s:mru = []
  let i = 0
  while i <= bufnr('$')
    let i += 1
    if !buflisted(i)
      continue
    endif
    call add(s:mru, i)
  endwhile
endfunction

function s:mru_remove(buffer)
  let index = index(s:mru, a:buffer)
  if index != -1
    call remove(s:mru, index)
  endif
endfunction

function s:mru_push()
  let buffer = bufnr('%')
  if !buflisted(buffer)
    return
  endif

  call s:mru_remove(buffer)
  call insert(s:mru, buffer, 0)
endfunction

function s:mru_pop()
  call s:mru_remove(bufnr('<afile>'))
endfunction

command B keepjumps :call <SID>display_buffer_list()

noremap <silent> <Leader>l :B<CR>

let s:previous_window = -1

let s:buffers_buffer = -1

function s:display_buffer_list()
  let window = bufwinnr(s:buffers_buffer)
  if window != -1
    execute window . 'wincmd w'
    return
  endif
  let s:previous_window = winnr()
  wincmd b
  let splitbelow_save = &splitbelow
  set splitbelow
  execute 'silent! keepalt new +setlocal\ modifiable\ noswapfile' .
        \ '\ buftype=nofile\ bufhidden=unload\ nobuflisted [Buffers]'
  let s:buffers_buffer = bufnr('%')
  let &splitbelow = splitbelow_save

  call s:setup_syntax()

  call s:build_buffer_list()

  call s:setup_mappings()

  call cursor(2, 1)
endfunction

function s:build_buffer_list()
  setlocal modifiable

  silent! 1,$d _
  normal! 0

  let n_listed_buffers = 0
  let max_listed_buffer_nr = 0
  for buffer in s:mru
    if !buflisted(buffer)
      call s:mru_remove(buffer)
      continue
    endif

    let n_listed_buffers += 1

    if buffer > max_listed_buffer_nr
      let max_listed_buffer_nr = buffer
    endif
  endfor

  let buffer_offset_width = strlen(n_listed_buffers)
  let buffer_number_width = strlen(max_listed_buffer_nr)

  let i = 0
  for buffer in s:mru
    let name = bufname(buffer)
    " TODO: hm…
    let cwd = getcwd()
    if cwd != ""
      let index = stridx(name, cwd)
      if index != -1
        let name = strpart(name, 0, index) . strpart(name, index + strlen(cwd) + 1)
      endif
    endif
    if exists("$HOME") && $HOME != ""
      let index = stridx(name, $HOME)
      if index == 0
        let name = '~' . strpart(name, index + strlen($HOME))
      endif
    endif
    if name == ""
      let name = '[No Name]'
    endif

    call append(line('$'),
              \ printf("%*d. %s",
              \        buffer_offset_width, i,
              \        name))
    let i += 1
  endfor
  1d _

  execute 'resize' line('$')
  setlocal winfixheight

  setlocal nomodifiable
endfunction

function s:setup_syntax()
  if !has('syntax')
    return
  endif

  syntax match buffersPath /^\s*\d\+\. \zs.*/

"  hi def link buffersPath Directory
endfunction

function s:setup_mappings()
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

function s:renumber_buffer_lines_below(lnum)
  set modifiable
  let lnum = a:lnum
  while lnum <= line('$')
    call setline(lnum, substitute(getline(lnum),
                                \ '^\(\s*\)\d\+\(. .*\)$',
                                \ '\1' . (lnum - 1) . '\2', ''))
    let lnum += 1
  endwhile
  set nomodifiable
endfunction

function s:remove_buffer_line(buffer)
  let index = index(s:mru, a:buffer)
  if index == -1
    return 0
  endif
  setlocal modifiable
  execute index . 'd _'
  setlocal nomodifiable
  if getline('$') == ""
    quit
  endif
  call s:renumber_buffer_lines_below(index)
  return 1
endfunction

function s:select_buffer(buffer)
  if !bufexists(a:buffer)
    echoerr printf("E86: Buffer %d does not exist", a:buffer)
    call s:remove_buffer_line(a:buffer)
  endif
  silent! close!
  execute s:previous_window . 'wincmd w'
  execute 'b' a:buffer
endfunction

function s:get_buffer_from_line(lnum)
  return s:mru[a:lnum - 1]
endfunction

function s:select_buffer_lnum(lnum)
  let buffer = s:get_buffer_from_line(a:lnum)
  if buffer == -1
    return
  endif
  call s:select_buffer(buffer)
endfunction

function s:select_buffer_nr(nr)
  call s:select_buffer_lnum(a:nr)
endfunction

function s:select_buffer_line()
  call s:select_buffer_lnum(line('.'))
endfunction

function s:delete_buffer(buffer)
  try
    " TODO: What a mess, but there are a bunch of edge cases here and the
    " problem is that I really don’t like it that all windows showing a buffer
    " disappear when the buffer is deleted.  This solution doesn’t work when
    " all windows are showing the given buffer and there is more than one
    " window.
    if winnr('$') == 2 && bufwinnr(a:buffer) != -1
      let win = winnr()
      execute bufwinnr(a:buffer) . 'wincmd w'
      let alternate = expand('#')
      if !buflisted(alternate)
        if alternate == ""
          bnext
        else
          new
        endif
      else
        execute 'b' alternate
      endif
      execute win . 'wincmd w'
    endif
    execute 'bd' a:buffer
  catch
    echoerr v:exception
  endtry
  if !buflisted(a:buffer)
    call s:remove_buffer_line(a:buffer)
  endif
endfunction

function s:delete_buffer_line()
  let buffer = s:get_buffer_from_line('.')
  if buffer == -1
    return
  endif
  call s:delete_buffer(buffer)
endfunction

let &cpo = s:cpo_save
