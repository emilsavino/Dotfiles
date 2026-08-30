# Shared shell configuration
#
# Machine-specific setup belongs in ~/.zshrc.local, which is intentionally
# not tracked by this repository.

export PATH="$HOME/.local/bin:$PATH"

if [[ -r "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# >>> colorful prompt >>>
# Show the current folder and Git branch/status without installing a prompt plugin.
autoload -Uz vcs_info
setopt prompt_subst

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr ' ✚'
zstyle ':vcs_info:git:*' unstagedstr ' ●'
zstyle ':vcs_info:git:*' formats ' %F{green}git:%b%f%F{yellow}%c%u%f'
zstyle ':vcs_info:git:*' actionformats ' %F{green}git:%b (%a)%f%F{yellow}%c%u%f'

prompt_precmd() {
    vcs_info
}
precmd_functions=(${precmd_functions:#prompt_precmd})
precmd_functions+=(prompt_precmd)

PROMPT='%F{cyan}%~%f${vcs_info_msg_0_} %F{magenta}❯%f '
# <<< colorful prompt <<<
