let g:vim_markdown_new_list_item_indent = 2

augroup MdcToMd
  if expand('%:e') ==# 'mdc'
    autocmd BufEnter *.mdc set filetype=markdown
  endif
augroup END

autocmd FileType markdown set shiftwidth=2

autocmd FileType markdown,cucumber map '' f\|
autocmd FileType markdown,cucumber map "" F\|
