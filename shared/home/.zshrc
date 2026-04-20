# --- 1. Environment & Paths ---
export EDITOR="$HOME/.local/share/bob/nvim-bin/nvim"
# Use array for PATH to avoid duplicates and handle spaces better
typeset -U path # This makes PATH unique automatically
path=(
    "$HOME/go/bin"
    "$HOME/.local/share/coursier/bin"
    "$HOME/.bun/bin"
    $path
)
export PATH

# Source env files
[[ -f "$HOME/.local/share/../bin/env" ]] && . "$HOME/.local/share/../bin/env"
[[ -f "$HOME/.local/share/bob/env/env.sh" ]] && . "$HOME/.local/share/bob/env/env.sh"

# --- 2. Zsh Modules & Basic Options ---
zmodload zsh/complist
autoload -Uz compinit && compinit
autoload -Uz colors && colors
autoload -Uz add-zsh-hook

# Options
setopt append_history inc_append_history share_history
setopt auto_menu menu_complete
setopt autocd auto_param_slash
setopt no_case_glob no_case_match
setopt globdots extended_glob interactive_comments
unsetopt prompt_sp
stty stop undef

# --- 3. History ---
HISTSIZE=1000000
SAVEHIST=1000000
HISTFILE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh_history"
HISTCONTROL=ignoreboth

# --- 4. Completion Styles ---
zstyle ':completion:*' menu select
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" ma=0\;33
zstyle ':completion:*' squeeze-slashes false
zstyle ':completion:*' special-dirs false

# --- 5. Keybinds (Vi mode) ---
bindkey -v
bindkey "^a" beginning-of-line
bindkey "^e" end-of-line
bindkey "^H" backward-kill-word
# Fix: Ensure logic is clean.
bindkey -r "^j"
bindkey -r "^J"
# bindkey "^J" history-search-forward
# bindkey "^K" history-search-backward
bindkey '^R' fzf-history-widget

# --- 6. Aliases ---
# Grouped by type
alias config='/usr/bin/git --git-dir=$HOME/dotfiles/ --work-tree=$HOME'
alias home='cd $HOME'
alias vi='nvim'
alias vim='nvim'
alias v="nvim"
alias cls='clear'
alias lg='lazygit'
alias oc='opencode'
alias ls='eza --icons=always --group-directories-first'
alias lsa='eza -a --icons=always --group-directories-first'
alias ll='eza -la --icons=always --group-directories-first'
alias lt='eza --tree --icons=always --group-directories-first'
alias poweroff="systemctl poweroff --no-wall"

# Helpful extras
alias llt='eza -la --sort=modified --icons=always' # Long list, sorted by time
alias lls='eza -la --sort=size --icons=always'     # Long list, sorted by size

# tmux stuff
alias tka='kitty-kill-sessionizer'
alias yay='paru'

# --- 7. Functions & Hooks ---
NEW_LINE_BEFORE_PROMPT=
show_newline() {
    # In Zsh, variables are global by default unless declared 'local'
    if [[ -z "$NEW_LINE_BEFORE_PROMPT" ]]; then
        NEW_LINE_BEFORE_PROMPT=1
    elif [[ "$NEW_LINE_BEFORE_PROMPT" -eq 1 ]]; then
        echo ""
    fi
}
add-zsh-hook precmd show_newline

# Define the function
my_zi_widget() {
    BUFFER="zi"
    zle accept-line
}

kitty_sessionizer_widget() {
    BUFFER="kitty-sessionizer"
    zle accept-line
}

# Register the widget
zle -N my_zi_widget
zle -N kitty_sessionizer_widget

# Bind to Ctrl+j
bindkey -M viins "^j" my_zi_widget
bindkey -M vicmd "^j" my_zi_widget
bindkey -M viins "^f" kitty_sessionizer_widget
bindkey -M vicmd "^f" kitty_sessionizer_widget


# --- 8. Plugin Initializations ---
# Use fzf if available
if (( $+commands[fzf] )); then
    source <(fzf --zsh)
fi

# Syntax highlighting (Check existence to avoid errors)
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# source /usr/share/nvm/init-nvm.sh

# --- 9. Final Init ---
# Starship replaces your manual prompt, so we initialize it last.
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
