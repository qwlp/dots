# --- 1. Environment & Paths ---
set -gx EDITOR "$HOME/.local/share/bob/nvim-bin/nvim"
set -gx MANPAGER "$HOME/.local/share/bob/nvim-bin/nvim +Man!"
set -gx KUBE_EDITOR "$HOME/.local/share/bob/nvim-bin/nvim"
# Enable a rich Git prompt without Starship
set -g __fish_git_prompt_show_informative_status 0
set -g __fish_git_prompt_showcolorhints 1
set -g __fish_git_prompt_showdirtystate 1
set -g __fish_git_prompt_showstashstate 1
set -g __fish_git_prompt_showuntrackedfiles 1
set -g __fish_git_prompt_showupstream informative
set -g __fish_git_prompt_status_order stagedstate invalidstate dirtystate untrackedfiles stashstate
set -g __fish_git_prompt_char_stateseparator ' '

# Nerd Font Status Indicators (Clean Style)
set -g __fish_git_prompt_char_dirtystate ' '       # Modified files (page with pencil/mark)
set -g __fish_git_prompt_char_stagedstate ' '     # Staged files (checkbox/plus)
set -g __fish_git_prompt_char_untrackedfiles ''  # Untracked files (question mark circle)
set -g __fish_git_prompt_char_stashstate ' '      # Stashed changes (package/box)
set -g __fish_git_prompt_char_upstream_ahead '⇡'   # Ahead of remote (up arrow)
set -g __fish_git_prompt_char_upstream_behind '⇣'  # Behind remote (down arrow)


if test -f "$HOME/.zprofile"
    for line in (string match --regex '^export [A-Za-z_][A-Za-z0-9_]*=.*$' < "$HOME/.zprofile")
        set -l pair (string replace --regex '^export ' '' -- "$line")
        set -l name (string replace --regex '=.*$' '' -- "$pair")
        set -l value (string replace --regex '^[^=]*=' '' -- "$pair" | string trim --chars='"')
        set -gx "$name" (string replace --all '$HOME' "$HOME" -- "$value")
    end
end

fish_add_path --global --move \
    "$HOME/go/bin" \
    "$HOME/.local/share/coursier/bin" \
    "$HOME/.bun/bin" \
    "$HOME/.local/share/nvim/mason/bin"

if test -f "$HOME/.local/share/bob/env/env.fish"
    source "$HOME/.local/share/bob/env/env.fish"
end

# --- 2. Aliases ---
alias config="/usr/bin/git --git-dir=$HOME/dotfiles/ --work-tree=$HOME"
alias home="cd $HOME"
alias vi="nvim"
alias vim="nvim"
alias v="nvim"
alias cls="clear"
alias lg="lazygit"
alias oc="opencode"
alias ls="eza --icons=always --group-directories-first"
alias lsa="eza -a --icons=always --group-directories-first"
alias ll="eza -la --icons=always --group-directories-first"
alias lt="eza --tree --icons=always --group-directories-first"
alias poweroff="systemctl poweroff --no-wall"
alias tpc="typst compile"
alias h="hx"

alias llt="eza -la --sort=modified --icons=always"
alias lls="eza -la --sort=size --icons=always"

alias tka="tmux kill-session"
alias yay="paru"
alias yolo='git add -A && git commit -m "yolo" && git push'

# --- 3. Functions & Keybinds ---
function show_newline --on-event fish_prompt
    if not set -q __new_line_before_prompt
        set -g __new_line_before_prompt 1
    else if test "$__new_line_before_prompt" -eq 1
        echo
    end
end

function my_zi_widget
    commandline --replace zi
    commandline --function execute
end

function tmux_sessionizer_widget
    commandline --replace tmux-sessionizer
    commandline --function execute
end

function fish_user_key_bindings
    fish_vi_key_bindings

    bind --mode insert \ca beginning-of-line
    bind --mode insert \ce end-of-line
    bind --mode insert \ch backward-kill-word
    bind --mode insert \cy accept-autosuggestion
    bind --mode insert \cj my_zi_widget
    bind --mode default \cj my_zi_widget
    bind --mode insert \cf tmux_sessionizer_widget
    bind --mode default \cf tmux_sessionizer_widget
end

# --- 4. Interactive Init ---
if status is-interactive
    set -g fish_greeting

    if type -q fzf
        fzf --fish | source
    end

    if type -q zoxide
        zoxide init fish | source
    end

end
