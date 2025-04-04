#
# ~/.bashrc
#
eval -- "$(/usr/bin/starship init bash --print-full-init)"
eval "$(zoxide init bash)"
# If not running interactively, don't do anything
[[ $- != *i* ]] && return
#TERM=xterm-256color
#[[ $- == *i* ]] && source /usr/share/blesh/ble.sh
# Aliases
export XDG_DATA_DIRS="$XDG_DATA_DIRS:/home/oscar/.guix-profile/share/"
alias ls='lsd'
alias grep='grep --color=auto'
export PASSWORD_STORE_DIR="/home/oscar/.local/share/pass"
PS1='[\u@\h \W]\$ '


[ -n "$EAT_SHELL_INTEGRATION_DIR" ] && \
  source "$EAT_SHELL_INTEGRATION_DIR/bash"

# Automatically added by the Guix install script.

if [ -n "$GUIX_ENVIRONMENT" ]; then
    if [[ $PS1 =~ (.*)"\\$" ]]; then
        PS1="${BASH_REMATCH[1]} [env]\\\$ "
    fi
fi

