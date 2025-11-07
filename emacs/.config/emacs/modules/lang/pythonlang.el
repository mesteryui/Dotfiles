;; -*- lexical-binding: t; -*- 
(use-package python
  :ensure nil
  :defer t
  ;;:hook (python-ts-mode-hook eglot-ensure)
  :mode (("\\.py\\'" . python-ts-mode))
  :config
  (setq python-indent-offset 4)
  (defun python-eglot-configs ()
    "Aplicar configuraciones de python especificas para eglot"
    (setq-local eglot-workspace-configuration
		'(:python (:pythonPath "python"
				       :analysis (:typeCheckingMode "basic"
								    :autoSearchPaths t
								    :useLibraryCodeForTypes t)))))
  (add-hook 'python-ts-mode-hook #'python-eglot-configs)
  (add-hook 'python-ts-mode-hook #'eglot-ensure))

(use-package pet
  :ensure t
  :defer t
  :hook (python-base-mode . pet-mode))

(use-package flymake-ruff
  :ensure t
  :hook (eglot-managed-mode . flymake-ruff-load))

;; -*- lexical-binding: t; -*-
(use-package uv
  :ensure (uv :type git :host github :repo "johannes-mueller/uv.el")
  :after tomlparse
  :init
  (add-to-list 'treesit-language-source-alist '(toml "https://github.com/tree-sitter-grammars/tree-sitter-toml"))
  (unless (treesit-language-available-p 'toml)
    (treesit-install-language-grammar 'toml)))

(use-package tomlparse
  :ensure (:type git :host github :repo "johannes-mueller/tomlparse.el
"))
(provide 'pythonlang)
