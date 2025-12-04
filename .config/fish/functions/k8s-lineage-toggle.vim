" k8s-lineage-toggle.vim - Toggle between simple and detailed lineage views
" Used by kubectl_fzf_native.fish Alt+L lineage command
" Uses script-local variables (s:) to persist across buffer switches

function! SetLineageFiles(simple, detailed)
  let s:simple = a:simple
  let s:detailed = a:detailed
  let s:view = 'simple'
endfunction

function! ToggleLineageView()
  let l:pos = getpos('.')
  if s:view == 'simple'
    exe 'edit ' . s:detailed
    let s:view = 'detailed'
  else
    exe 'edit ' . s:simple
    let s:view = 'simple'
  endif
  setlocal ft=yaml readonly nomodified
  call setpos('.', l:pos)
  nnoremap <buffer> <A-d> :call ToggleLineageView()<CR>
endfunction
