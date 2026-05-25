# /etc/profile.d/bero-shell.sh
# Workshop polish for interactive bash: aliases, history, command-not-found.

case $- in *i*) ;; *) return ;; esac

# History
export HISTSIZE=20000
export HISTFILESIZE=40000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT='%F %T  '
shopt -s histappend cmdhist

# Completion niceness
shopt -s checkwinsize globstar nocaseglob

# Useful aliases (no flair, just defaults that should have been default)
alias ll='ls -lh --color=auto'
alias la='ls -lha --color=auto'
alias l='ls -CF --color=auto'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias diff='diff --color=auto'
alias mv='mv -i'
alias cp='cp -i'
alias rm='rm -i'
alias mkdir='mkdir -p'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias path='echo -e ${PATH//:/\\n}'
alias reload='exec $SHELL -l'
alias please='sudo'

# Claude
alias claude-yolo="claude --dangerously-skip-permissions"

# Bero
alias bero-info='bero info'
alias workshop='bero workshop'

# command_not_found_handle — workshop-voice hint
command_not_found_handle() {
    local cmd="$1"
    local R=$'\033[38;2;200;16;46m'
    local M=$'\033[38;2;122;116;104m'
    local X=$'\033[0m'
    printf '%s▮%s no such command: %s%s%s\n' "$R" "$X" "$M" "$cmd" "$X" >&2
    if command -v bero >/dev/null 2>&1; then
        local hint
        hint=$(shuf -n 1 /usr/local/share/bero-os/workshop-wisdom.txt 2>/dev/null)
        [ -n "$hint" ] && printf '   %s%s%s\n' "$M" "$hint" "$X" >&2
    fi
    return 127
}
