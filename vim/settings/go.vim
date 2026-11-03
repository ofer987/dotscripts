let g:go_def_mode='gopls'
let g:go_info_mode='gopls'
let g:go_list_type = "quickfix"

autocmd FileType go nnoremap <leader>fw :GoAlternate<CR>
