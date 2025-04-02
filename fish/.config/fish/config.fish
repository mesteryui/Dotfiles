set -U fish_user_paths -g ~/.cargo/bin ~/.local/bin ~/ /usr/local/bin ~/.local/share/pipx/venvs
#set -Ux GSETTINGS_SCHEMA_DIR "/usr/share/glib-2.0/schemas"
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
    #syncthing
    #syncthing install-completions | source
    fzf --fish | source
    # Television
    #tv init fish | source
end
set TERM "xterm-256color"                         # Sets the terminal type
alias unlock='sudo rm /var/lib/pacman/db.lck'
alias removeorphan 'sudo pacman -Rsn $(pacman -Qtdq)'
#alias ssh='wezterm ssh'
alias "unimatrix" "unimatrix -n -s 96"
alias "tiempo" 'curl wttr.in/Vigo'
alias rem="pkill emacsclient && systemctl restart --user emacs" # Kill Emacs and restart daemon..
#alias "tree" 'eza --tree'
#set -x QT_QPA_PLATFORMTHEME 'qt5ct'
set -x PASSWORD_STORE_DIR '/home/oscar/.local/share/pass'
set -x NNTPSERVER 'snews://news.eternal-september.org'
alias "yt-watch" 'yt-dlp -o "/tmp/%(title)s.%(ext)s" --restrict-filenames --sponsorblock-remove sponsor --exec "xdg-open {} && sleep 10 && rm {}"'
#set EDITOR "emacsclient -t -a ''"                 # $EDITOR use Emacs in terminal
set VISUAL "emacsclient -c -a emacs"
set EDITOR "emacsclient -t -a ''"                 # $EDITOR use Emacs in terminal
set -Ux LOCALE "es_ES.UTF-8"
set -Ux FZF_DEFAULT_OPTS "\
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"
