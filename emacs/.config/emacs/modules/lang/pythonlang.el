(use-package python
  :after eglot
  :ensure nil
  :hook (python-ts-mode-hook eglot-ensure)
  :mode (("\\.py\\'" . python-ts-mode))
  :config (setq python-indent-offset 4))
;;(add-hook 'python-ts-mode-hook #'eglot-ensure)

(use-package pet
  :ensure t
  :defer t
  :hook (python-base-mode . pet-mode))

(use-package flymake-ruff
  :ensure t
  :hook (python-ts-mode . flymake-ruff-load))

;; -*- lexical-binding: t; -*-
(use-package uv
  :ensure (uv :type git :host github :repo "johannes-mueller/uv.el")
  :init
  (add-to-list 'treesit-language-source-alist '(toml "https://github.com/tree-sitter-grammars/tree-sitter-toml"))
  (unless (treesit-language-available-p 'toml)
    (treesit-install-language-grammar 'toml)))

(use-package tomlparse
  :ensure (:type git :host github :repo "johannes-mueller/tomlparse.el
"))
(provide 'pythonlang)
