local brew_path="/opt/homebrew/bin"
local brew_opt_path="/opt/homebrew/opt"
local nvm_path="$HOME/.nvm"
local pipenv_path="Library/Python/3.11/bin"

alias pn=pnpm

export PATH="${brew_path}:${PATH}"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

# Load Angular CLI autocompletion.
# source <(ng completion script)
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH="$PATH:$HOME/${pipenv_path}"

# Created by `pipx` on 2024-04-14 09:48:00
export PATH="$PATH:/Users/tim/.local/bin"

export PATH="$HOME/.local/bin:$PATH"