" Format code
autocmd FileType c,cpp,objc nnoremap <buffer><Leader>c= :<C-u>ClangFormat<CR>
autocmd FileType c,cpp,objc vnoremap <buffer><Leader>c= :ClangFormat<CR>

" Toggle auto formatting:
nmap <Leader>C :ClangFormatAutoToggle<CR>

if has('nvim')
  map <silent> <leader>cc :CocCommand clangd.switchSourceHeader<cr>
endif
