if status is-interactive
    # Commands to run in interactive sessions can go here
    set -g fish_greeting
    #set -x MANPAGER "nvim +Man!"
    set -g TERM kitty
    # starship
    starship init fish | source
    # atuin
    atuin init fish | source
    # zoxide
    zoxide init fish | source
    thefuck --alias | source
    #syncthing
    #syncthing install-completions | source
    sk --shell fish | source
    # Television
    #tv init fish | source
end
set -Ux GEM_HOME $HOME/.gem/ruby/(ruby -e 'print RUBY_VERSION')
set -U fish_user_paths -g ~/.cargo/bin ~/.local/bin ~/ /usr/local/bin ~/.local/share/pipx/venvs $GEM_HOME/bin
set -gx XDG_RUNTIME_DIR "/run/user/$(id -u)"


set VISUAL "emacsclient -c -a emacs"
set EDITOR "emacsclient -t -a ''"
set -x PASSWORD_STORE_DIR '/home/oscar/.local/share/pass'
set -x NNTPSERVER 'snews://news.eternal-september.org'

alias "emacsc" "emacsclient -c -a emacs"

alias "ls" "lsd"
alias "yt-watch" 'yt-dlp -o "/tmp/%(title)s.%(ext)s" --restrict-filenames --sponsorblock-remove sponsor --exec "xdg-open {} && sleep 10 && rm {}"'
alias unlock='sudo rm /var/lib/pacman/db.lck'
alias removeorphan 'sudo pacman -Rsn $(pacman -Qtdq)'
#alias ssh='wezterm ssh'
alias "unimatrix" "unimatrix -n -s 96"
alias "tiempo" 'curl wttr.in/Vigo'
alias rem="pkill emacsclient && /usr/bin/emacs --daemon &" # Kill Emacs and restart daemon..


# Abreviatures
abbr .. 'cd ..'
abbr ... 'cd ../..'
abbr .3 'cd ../../..'
abbr .4 'cd ../../../..'
abbr .5 'cd ../../../../..'
