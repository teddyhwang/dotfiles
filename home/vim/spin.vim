let g:gh_open_command = 'fn() { echo "$@" | pbcopy-remote; }; fn '

nnoremap <silent> <leader>p :call PopulatePasteBufferFromOSX()<cr>
nnoremap <silent> <leader>y :call PropagatePasteBufferToOSX()<cr>

function! PropagatePasteBufferToOSX()
  let @n=getreg("*")
  call system('pbcopy-remote', @n)
  echo "clipboard sent"
endfunction

function! PopulatePasteBufferFromOSX()
  let @+ = system('pbpaste-remote')
  echo "clipboard received"
endfunction
