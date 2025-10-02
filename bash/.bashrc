
# ~/.bashrc

eval -- "$(/usr/bin/starship init bash --print-full-init)"
eval "$(zoxide init bash)"
# If not running interactively, don't do anything
[[ $- != *i* ]] && return
#TERM=xterm-256color
#[[ $- == *i* ]] && source /usr/share/blesh/ble.sh
# Aliases
#export XDG_DATA_DIRS="$XDG_DATA_DIRS:/home/oscar/.guix-profile/share/"
#export XDG_RUNTIME_DIR="/run/user/$(id -u)"
#export DISPLAY=:0
#export WAYLAND_DISPLAY=wayland-1
alias ls='lsd'
alias grep='grep --color=auto'
export PASSWORD_STORE_DIR="/home/$USER/.local/share/pass"
PS1='[\u@\h \W]\$ '
alias emacsc="emacsclient -c -a emacs"

[ -n "$EAT_SHELL_INTEGRATION_DIR" ] && \
  source "$EAT_SHELL_INTEGRATION_DIR/bash"

#[ -t 1 ] && exec fish
## Fin de archivo 

#source /home/oscar/.config/broot/launcher/bash/br
