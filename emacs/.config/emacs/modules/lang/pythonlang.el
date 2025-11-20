;; -*- lexical-binding: t; -*- 
(use-package python
  :ensure nil
  ;;:hook (python-ts-mode-hook eglot-ensure)
  :custom
  (python-indent-guess-indent-offset nil)
  :config
  (setq python-indent-offset 4)
  (defun python-eglot-configs ()
    "Aplicar configuraciones de python especificas para eglot"
    (setq-local eglot-workspace-configuration
		'(:python (:pythonPath "python"
				       :analysis (:typeCheckingMode "off"
								    :autoSearchPaths t
								    :useLibraryCodeForTypes t))))
    (eglot-ensure))
  (add-hook 'python-ts-mode-hook #'python-eglot-configs))

(use-package pet
  :ensure t
  :hook (python-base-mode . pet-mode))

;; (use-package flymake-ruff
;;   :ensure t
;;   :hook (eglot-managed-mode . flymake-ruff-load))

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
