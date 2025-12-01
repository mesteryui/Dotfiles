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
								    :useLibraryCodeForTypes nil
								    :exclude ["**/__pycache__"]))))
    (eglot-ensure))
  (add-hook 'python-ts-mode-hook #'python-eglot-configs))

(use-package pet
  :config
  (add-hook 'python-base-mode-hook 'pet-mode -10))

;; (use-package flymake-ruff
;;   :ensure t
;;   :hook (eglot-managed-mode . flymake-ruff-load))

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

(with-eval-after-load 'apheleia
  (setf (alist-get 'ruff apheleia-formatters)
        '("ruff" "format" "--silent" "--stdin-filename" filepath "-"))
  (setf (alist-get 'ruff-isort apheleia-formatters)
        '("ruff" "check" "--select" "I" "--fix" "--silent" "--stdin-filename" filepath "-"))
  (setf (alist-get 'python-mode apheleia-mode-alist)
	'(ruff-isort ruff))
  (setf (alist-get 'python-ts-mode apheleia-mode-alist)
	'(ruff-isort ruff)))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '(python-mode . ("pyright-langserver" "--stdio"))))

(with-eval-after-load 'dape
  (add-to-list 'dape-configs
	       `(python-debug
                 :description "Python (debugpy)"
                 modes (python-mode python-ts-mode)
                 command "python3"
                 command-args ("-m" "debugpy.adapter")
                 :type "executable"            ; usar "executable" para debugpy
                 :request "launch"
                 :cwd dape-cwd-fn
                 :program ,(or (buffer-file-name) "/tmp/fallback.py"))))
(provide 'pythonlang)
