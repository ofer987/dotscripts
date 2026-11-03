let g:lsp_clangd_ignore_warning = 1

autocmd BufEnter *.h set ft=c

function! s:switch_from_source_to_test()
  let l:filepath = expand("%:~")
  let l:filename = expand("%:t")
  let l:dirname = expand('%:p:h')

  if l:filepath =~ '\/tests\/test_\(\w\+\)\.c$'
    let l:source_code = substitute(l:filepath, 'tests\/test_\(\w\+\)\.c$', '\1\.c', '')

    if filereadable(expand(l:source_code))
      execute 'e ' . l:source_code
    else
      echo "Source file " . l:source_code . " does not exist"
    endif
  else
    let l:file_base_name = substitute(l:filename, '\(\w\+\)\.\w$', '\1', '')

    let l:test_path = l:dirname . '/tests/test_' . l:file_base_name . '.c'

    if filereadable(expand(l:test_path))
      execute 'e ' . l:test_path
    else
      echo "Test file " . l:test_path . " does not exist"
    endif
  endif
endfunction

command! SwitchFromSourceToTest call s:switch_from_source_to_test()
map <silent> <leader>cy :SwitchFromSourceToTest<cr>
