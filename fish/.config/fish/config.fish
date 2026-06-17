#source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
if status is-interactive
    # Commands to run in interactive sessions can go here
    set -g fish_greeting
    #set -x MANPAGER "nvim +Man!"
    set -g TERM kitty
    # starship
    starship init fish | source
    # atuin
    #atuin init fish | source
    # zoxide
    zoxide init fish | source
    #syncthing
    #syncthing install-completions | source
    sk --shell fish | source
end
#set -Ux GEM_HOME $HOME/.gem/ruby/(ruby -e 'print RUBY_VERSION')
fish_config theme choose Matugen
alias ls 'eza --icons'
alias cat bat
alias cd z
set -U fish_user_paths -g ~/.cargo/bin ~/.local/bin ~/ /usr/local/bin ~/.local/share/pipx/venvs "~/.gem/ruby/3.4.0/bin/" ~/.roswell/bin
#set -gx XDG_RUNTIME_DIR "/run/user/$(id -u)"
# set -Ux XDG_CONFIG_HOME $HOME/.config
# set -Ux XDG_DATA_HOME $HOME/.local/share
# set -Ux XDG_STATE_HOME $HOME/.local/state
# set -Ux XDG_CACHE_HOME $HOME/.cache
set TERM "xterm-256color"
set VISUAL "emacsclient -c -a emacs"
set EDITOR "emacsclient -t -a ''"
set -Ux PASSWORD_STORE_DIR '/home/oscar/.local/share/pass'
set -x NNTPSERVER 'snews://news.eternal-september.org'
alias config "git --git-dir=$HOME/.dotfiles/.git --work-tree=$HOME/.dotfiles"


# Added by LM Studio CLI (lms)
set -gx PATH $PATH /home/oscar/.lmstudio/bin
# End of LM Studio CLI section



# Added by Antigravity CLI installer
set -gx PATH "/home/oscar/.local/bin" $PATH
