(setopt erc-nick "mester")
(setq erc-prompt-for-password (string-trim (shell-command-to-string "cat ~/Descargas/Conjuntos\\ contraseña/password_irc")))
(setq erc-track-enable-keybindings t)
(setopt erc-fill-column 120
	erc-fill-function 'erc-fill-static
	erc-fill-static-center 20)

(provide 'tools)
