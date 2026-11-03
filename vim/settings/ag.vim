" Open the Ag command and place the cursor into the quotes
nmap <leader>ag :Ag! ""<Left>
vmap <leader>ag y:Ag! ""<Left><C-r>"<cr>
vmap F y:Ag! ""<Left><C-r>"<cr>
