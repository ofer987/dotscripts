let g:ale_enabled = 1
let g:ale_emit_conflict_warnings = 0

nnoremap <leader>afu :ALEFindReferences<CR>
nnoremap <leader>afd :ALEGoToDefinition<CR>
nnoremap <leader>aft :ALEGoToTypeDefinition<CR>

autocmd FileType ruby map <C-n> :ALENextWrap<CR>
autocmd FileType ruby map <C-p> :ALEPreviousWrap<CR>

nnoremap <leader>ap :ALEPreviousWrap<CR>
nnoremap <leader>an :ALENextWrap<CR>
nnoremap <leader>ai :ALEInfo<CR>
nnoremap <leader>ao :ALEDetail<CR>
nnoremap <leader>ac :pclose<CR>

map <C-n> :ALENextWrap<CR>
map <C-p> :ALEPreviousWrap<CR>

nnoremap <leader>aff :ALEFix<CR>

let g:ale_linters = {
      \ 'markdown': ['writegood'],
      \ 'cs': ['OmniSharp', 'dotnet-format', 'csc'],
      \ 'c': ['clangd', 'clangtidy', 'clangcheck'],
      \ 'python': [],
      \ }
let g:ale_cs_dotnet_format_executable = 'dotnet'
let g:ale_fixers = {
      \ 'cs': ['dotnet-format', 'remove_trailing_lines', 'trim_whitespace'],
      \ '*': ['remove_trailing_lines', 'trim_whitespace'],
      \ 'c': ['clang-format'],
      \ 'javascript': ['eslint'],
      \ }
" let g:ale_fixers = { 'dotnet-format' }
let g:ale_pattern_options = {
      \ '\.tsx?$': {'ale_enabled': 0},
      \ '\.s?css$': {'ale_enabled': 0}
      \ }
