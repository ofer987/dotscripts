# Key Mappings

## Tmux

Name | Key Map | Description
---- | ------- | -----------
Start new session | `tmux new-session -s <session-name> -n <window-name>`
Attach to existing Tmux session | `tmux attach`
Move window | `<C-A>.` OR `<C-A><C-.>`
Rename window | `<C-A>,` OR `<C-A><C-,>`
Previous and next session | `<C-A>(` AND `<C-A>)`
Previous window | `<C-A><C-A>`
Zoom into pane | `<C-A><C-Z>`
Kill pane | `<C-A><C-X>`

## Neovim

Name | Key Map | Description
---- | ------- | -----------
Previous buffer | `<leader>z`
Next buffer | `<leader>x`
Last edit location | `<leader>.`
Open NERDTree | `<leader><backtick>`
Show file location in NERDTree | `<C-\>`
Open **Quickfix List** | `<leader>qo`
Close **Quickfix List** | `<leader>qc`
Previous item in **Quickfix List** | `<leader>qp`
Next item in **Quickfix List** | `<leader>qn`
Open **ALEDetail** | `<leader>ao`
Close **ALEDetail** | `<leader>ac`
Previous item in **ALEDetail** | `<C-P>`
Next item in **ALEDetail** | `<C-N>`
Change file using CtrlP | `<leader>t`
Refresh CtrlP cache | `<leader>ct`
Change buffer using CtrlP | `<leader>b`
Stop highlighting | `//`
Highlight previously selected words | `gv`
Turn on British English spell checker | `<leader>son`
Turn off British English spell checker | `<leader>soff`
Synchronise spellings | `<leader>sync`
Previous spelling mistake | `[s`
Next spelling mistake | `]s`
Spelling suggestions | `z=`
Add new word | `zg`
Copy filename | `<leader>cn`
Copy filepath | `<leader>cf`
Echo filename | `<leader>ln`
Echo filepath | `<leader>lf`
Open Help tab | `:thelp`
Switch between Work tab and Help tab | `<C-W><C-t>`
ALE Fix | `<leader>aff`
dotnet- format | `<leader>qf`

### Files that support Language Server Processor

Name | Key Map | Description
---- | ------- | -----------
Find usages | `<leader>fu`
Go to definition | `gd` OR `<leader>gd`
Go to implementation | `<leader>fi`
Go to type definition | `<leader>ft`
Rename | `<leader>nm`
Hover (see definition) | `K` OR `<leader>K`
Previous item in **ALEDetail** | `<C-P>`
Next item in **ALEDetail** | `<C-N>`

### Files that support the OmniSharp Server

Name | Key Map | Description
---- | ------- | -----------
Find usages | `<leader>fu`
Go to definition | `gd`
Go to implementations | `<leader>fi`
Go to type definition | `<leader>ft`
Rename | `<leader>nm`
Previous diagnostic | `[g`
Next diagnostic | `]g`
Hover (see definition) | `<leader>dc`
Previous function | `[[`
Next function | `]]`
Format the code | `<leader>c=`
