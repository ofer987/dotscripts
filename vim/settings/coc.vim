if has('nvim')
  let g:coc_disable_startup_warning = 1

  autocmd BufEnter * let g:coc_start_at_startup = 0

  autocmd BufEnter *.rb,*.sh,*.tsx,*.js,*.ts,*.css,*.scss,*.less,*.json,*.go,*.ps1,*.py,*.svelte let g:coc_start_at_startup = 1
  autocmd BufEnter *.rb,*.sh,*.tsx,*.js,*.ts,*.css,*.scss,*.less,*.json,*.go,*.ps1.*.py,*.svelte call execute('CocEnable')

  autocmd FileType scss setl iskeyword+=@-@
  " Do not change cursor style if <C-c> is pressed
  let g:coc_disable_transparent_cursor = 1

  " Some servers have issues with backup files, see #649.
  set nobackup
  set nowritebackup

  " Having longer updatetime (default is 4000 ms = 4 s) leads to noticeable
  " delays and poor user experience.
  set updatetime=300
  " Always show the signcolumn, otherwise it would shift the text each time
  " diagnostics appear/become resolved.
  set signcolumn=yes

  " Use <C-e> for trigger completion with characters ahead and navigate.
  " NOTE: There's always complete item selected by default, you may want to enable
  " no select by `"suggest.noselect": true` in your configuration file.
  " NOTE: Use command ':verbose imap <C-e>' to make sure <C-e> is not mapped by
  " other plugin before putting this into your config.
  inoremap <silent><expr> <C-e>
        \ coc#pum#visible() ? coc#pum#confirm() :
        \ CheckBackspace() ? "\<C-e>" :
        \ coc#refresh()

  function! CheckBackspace() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
  endfunction

  " TypeScript
  " npm install -g typescript typescript-language-server
  " And then run :CocInstall coc-tsserver in Neovim
  nmap <silent> gd <Plug>(coc-definition)
  map <silent> <leader>ft <Plug>(coc-type-definition)
  map <silent> <leader>fi <Plug>(coc-implementation)
  map <silent> <leader>fu <Plug>(coc-references)
  map <silent> <leader>nm <Plug>(coc-rename)

  " Cycle errors for all filetypes
  " autocmd BufEnter * map <leader>an :ALENextWrap<CR>
  " autocmd BufEnter * map <leader>ap :ALEPreviousWrap<CR>

  " But use Coc for these filetypes because it works better!
  map <C-n> <Plug>(coc-diagnostic-next)
  map <C-p> <Plug>(coc-diagnostic-prev)

  map <silent> <leader>fl :CocList<cr>
  map <silent> <leader>fh :CocList outline -kind class<cr>
  map <silent> <leader>fj :CocList outline -kind method<cr>
  map <silent> <leader>fk :CocList outline -kind function<cr>


  map <silent> gk :CocPrev<cr>
  map <silent> gj :CocNext<cr>
  map <silent> <leader>gk :CocPrev<cr>
  map <silent> <leader>gj :CocNext<cr>

  function! s:format_all_open_file_buffers() abort
    for l:buf in range(1, bufnr('$') - 2)
      exe 'buffer' l:buf

      call CocAction('format')
      w
    endfor
  endfunction
  command! FormatAllOpenBuffers call s:format_all_open_file_buffers()
  command! Fall call s:format_all_open_file_buffers()
  command! Fwall call s:format_all_open_file_buffers()
else
endif
