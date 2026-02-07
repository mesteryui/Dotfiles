;;; os-toml.el --- TOML configuration -*- lexical-binding: t; -*-

(require 'os-macros)

(use-package toml-ts-mode
  :ensure nil
  ;; :hook
  ;;((toml-ts-mode . apheleia-mode))
  ;;(toml-ts-mode . eglot-ensure))
  :config
  ;;(os/after eglot
  ;;	    (add-to-list 'eglot-server-programs
  ;;			 '(toml-ts-mode . ("taplo" "lsp" "stdio")))))
  )

(provide 'os-toml)
