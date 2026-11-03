# Dot Scripts

Personal dot files. They belong to me, and me only. You can obviously contribute; or fork. Whatever, do what you want. There is no licence.

## Installation Instructions

| Technology  | Install Command                                                                                    | Latest Instructions                                                                                                         |
| ----------- | -------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| iTerm2      | N/A                                                                                                | https://iterm2.com                                                                                                          |
| Brew        | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)";` | https://github.com/Homebrew/brew                                                                                            |
| Neovim      | `brew install neovim;`                                                                             | https://github.com/neovim/neovim                                                                                            |
| Vim         | `brew install vim;`                                                                                | https://github.com/vim/vim                                                                                                  |
| Tmux        | `brew install tmux;`                                                                               |
| Fish        | `brew install fish;`                                                                               | https://fishshell.com/                                                                                                      |
| zoxide      | `brew install zoxide`                                                                              | https://github.com/ajeetdsouza/zoxide                                                                                       |
| fzf         | `brew install fzf`                                                                                 | https://github.com/junegunn/fzf                                                                                             |
| Fisher      | `curl -sL https://git.io/fisher \| source && fisher install jorgebucaran/fisher;`                  | https://github.com/jorgebucaran/fisher                                                                                      |
| Karabiner   | N/A                                                                                                | https://github.com/pqrs-org/Karabiner-Elements                                                                              |
| Pry         | `gem install pry;`                                                                                 | https://github.com/pry/pry                                                                                                  |
| NVM         | `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh \| bash;`                | https://github.com/nvm-sh/nvm                                                                                               |
| Git Scripts | N/A                                                                                                | Set the GitHub Personal Authentication Token as `env -x GITHUB_TOKEN <personal-pat>` in `~/.yadr/fish/config.personal.fish` |

## Configuration Instructions

### Git-scripts submodule

1. `git submodule update --recursive;`

### Artificial Intelligence

1. `ln -s ~/.yadr/claude/skills ~/.claude/skills`
1. `ln -s ~/.yadr/claude/agents ~/.claude/agents`

### Fish and Starship

1. `mkdir -p -- ~/.config;`
1. `ln -s ~/.yadr/fish ~/.config/fish;`
1. `ln -s ~/.yadr/starship.toml ~/.config/starship.toml;`
1. `curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher;`
1. `fisher install edc/bass;`
1. `fisher install oh-my-fish/theme-coffeeandcode;`
1. `fisher install dracula/fish;`

### Make Fish be the Default Shell

1. Add the result of `which fish` to `/etc/shells`
1. `chsh -s $(which fish)` in Bash

### iTerm2

1. Load settings from `~/.yadr/iTerm2`, Preferences -> General -> Preferences

### Starship Cross-shell Prompt

1. Follow the instructions at https://starship.rs/
1. Install the NerdFont FiraCode font for iTerm2

### Node && Yarn

1. `nvm install 14.17`
1. `nvm install 18.14`
1. `ln -s ~/.yadr/nvmrc ~/.nvmrc`
1. `npm install --global yarn`

### IntelliJ IDEA

1. `defaults write com.jetbrains.intellij ApplePressAndHoldEnabled -bool false`

### .NET Core

Install from [Microsoft](https://dotnet.microsoft.com/en-us/download).

Install in the home directory (~) on Thomson Reuters computers because of permissions.

### C/C++

Copy the `.clang-format` files into your C/C++ projects that are compiled with Clang.

### Python

1. Install pyenv, `brew install pyenv`
2. Install pipx, `brew install pipx`, and follow extra instructions at https://pypi.org/project/pipx/
3. Install pipenv, `pipx install pipenv`

### Neovim and Vim

Install both Neovim and Vim via Brew, and then run,

1. `pip3 install pynvim --upgrade`
1. `yarn global add neovim`
1. `gem install neovim`

#### Configure GitHub Copilot

1. `:Copilot setup`
1. `:Copilot enable`

#### vim-plug

1. Install vim-plug, https://github.com/junegunn/vim-plug, for both Neovim and Vim

#### Plugins

1. `ln -s ~/.yadr/vim ~/.vim;`
1. `ln -s ~/.yadr/vimrc ~/.vimrc;`
1. `mkdir -p -- ~/.config/nvim;`
1. `ln -s ~/.yadr/vimrc ~/.config/nvim/init.vim;`
1. `ln -s ~/.yadr/vim/spell ~/.config/nvim/spell;`
1. `nvim +PlugClean +PlugInstall +PlugUpdate;`
1. `vim +PlugClean +PlugInstall +PlugUpdate;`
1. `vim +OmniSharpInstall;`

#### Language Servers

1. `gem install rubocop;`
1. `ln -s ~/.yadr/rubocop/config.yml ~/.rubocop.yml;`
1. `ln -s ~/.yadr/ruby/ruby-version ~/.ruby-version;`
1. `npm install -g vim-language-server;`
1. `gem install solargraph;`
1. `mkdir -p ~/.config/solargraph;`
1. `ln -s ~/.yadr/solargraph.yml ~/.config/solargraph/config.yml;`
1. `pip install python-language-server;`
1. `npm install -g typescript typescript-language-server;`
1. `npm install -g bash-language-server;`
1. `npm install -g vscode-css-languageserver-bin;`
1. `npm install -g vscode-html-languageserver-bin;`
1. `npm install -g dockerfile-language-server-nodejs;`
1. `brew install llvm;`
1. `ln -s ~/.yadr/nvmrc ~/.nvmrc`
1. For TypeScript (via CoC):
   - execute in Neovim: `:CocInstall coc-tsserver`
   - execute in Neovim: `:CocInstall coc-css`
   - execute in Neovim: `:CocInstall coc-json`
   - execute in Neovim: `:CocInstall coc-solargraph`
   - execute in Neovim: `:CocInstall coc-powershell`
   - execute in Neovim: `:CocInstall coc-clangd`
   - execute in Neovim: `:CocInstall coc-pyright`
   - execute in shell: `ln -s ~/.yadr/coc-settings.json ~/.config/nvim/coc-settings.json;`
   - There are more commands, just find them under [plugs.nvim](./vim/plugs.nvim)

Configure Solargraph by following its [documentation](https://github.com/castwide/solargraph)

### Git

1. `ln -s ~/.yadr/git/gitconfig ~/.gitconfig`

### Tmux

1. `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm;`
1. `~/.tmux/plugins/tpm/tpm;`
1. `ln -s ~/.yadr/tmux/tmux.conf ~/.tmux.conf;`
1. `ln -s ~/.yadr/tmux/tmux.user.conf ~/.tmux.user.conf;`
1. Run `~/.tmux/plugins/tpm/tpm`

- If the Plugins do not exist at `~/.tmux/plugins` then install them manually
  1. `git clone https://github.com/tmux-plugins/tpm`
  1. `git clone git@github.com:tmux-plugins/tmux-yank.git`
  1. `git clone git@github.com:ofer987/tmux-airline-dracula.git`

1. Silence bell:
1. Preferences -> Profiles -> Terminal -> Silence bell
1. Fonts:
1. Font Book -> Add -> `~/.yadr/fonts/Fira Code Regular Nerd Font Complete.otf`
1. Preferences -> Profiles -> Text -> FiraCode Nerd Font
1. Meta Key:
1. Preferences -> Profiles -> Keys -> General -> **Left Option Key** set to `Esc+`

### Pry

1. `ln -s ~/.yadr/irb/pryrc ~/.pryrc;`
1. `ln -s ~/.yadr/irb/aprc ~/.aprc;`

### Karabiner

1. `ln -s ~/.yadr/karabiner ~/.config/karabiner;`

### LaunchBar

1. Install LaunchBar from http://launchbar.com
1. Licence can be found in \*\*\*@gmail.com email inbox
1. Install custom actions by executing, `~/.yadr/launch_bar/create_action`

## Future Plans

TODO: Consider moving the entire ~/.config directory into ~/.yadr and then adding a .gitignore file within it to preclude machine-dependent files

## Key Mappings

[Key Mappings](./keymappings.md)

## Chrome

1. Install [Rearrange Tabs](https://chrome.google.com/webstore/detail/rearrange-tabs/ccnnhhnmpoffieppjjkhdakcoejcpbga)
1. Install [Pin Tab](https://chrome.google.com/webstore/detail/pin-tab/dgldedkigbbalaioohedddpameekglma)
1. Install [Autocrate](https://github.com/ofer987/autocrate)
1. Install [Bavardo](https://github.com/ofer987/bavardo)
