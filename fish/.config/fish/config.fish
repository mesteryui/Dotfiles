set -U fish_user_paths -g ~/.cargo/bin ~/.local/bin ~/ /usr/local/bin ~/.local/share/pipx/venvs

if status is-interactive
    # Commands to run in interactive sessions can go here
    set -g fish_greeting
    set -x MANPAGER "nvim +Man!"
    fish_config theme choose "Catppuccin Mocha"
    set -g TERM kitty
    # starship
    starship init fish | source
    # atuin
    atuin init fish | source
    # zoxide
    zoxide init fish | source
    #syncthing
    #syncthing install-completions | source
    fzf --fish | source
end
alias "configure" 'cd ~/.config && nvim $(fzf --preview="bat --color=always {}") && cd'
alias "ls" 'lsd'
#alias "unimatrix" "unimatrix -n -s 96"
alias "vetero" 'curl wttr.in/Vigo'
#alias "tree" 'eza --tree'
#set -x QT_QPA_PLATFORMTHEME 'qt5ct'
set -x PASSWORD_STORE_DIR '/home/oscar/.local/share/pass'
set -x XDG_CONFIG_DIR '/home/oscar/.config'
set -x NNTPSERVER 'snews://news.eternal-september.org'
alias "yt-watch" 'yt-dlp -o "/tmp/%(title)s.%(ext)s" --restrict-filenames --sponsorblock-remove sponsor --exec "xdg-open {} && sleep 10 && rm {}"'
#alias "cd" "z"
set -x EDITOR "nvim"
set -Ux FZF_DEFAULT_OPTS "\
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
