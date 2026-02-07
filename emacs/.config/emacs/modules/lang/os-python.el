;;; os-python.el --- Python configuration -*- lexical-binding: t; -*-

(use-package python
  :ensure nil
  :custom
  (python-indent-guess-indent-offset nil)
  :config
  (setq python-indent-offset 4)
  
  (defun python-eglot-configs ()
    "Optimized Eglot configuration for Python to avoid freezing."
    ;; Performance: Increase timeout and limit unnecessary traffic
    (setq-local jsonrpc-default-request-timeout 30)
    (setq-local eglot-send-changes-idle-time 0.5)
    (setq-local eglot-events-buffer-size 0) ;; Disable logging for speed
    
    (setq-local eglot-workspace-configuration
                '(:basedpyright
                  (:analysis (:autoSearchPaths nil
					       :useLibraryCodeForTypes nil
					       :diagnosticMode "openFilesOnly" ;; Only analyze open files (Huge speedup)
					       :typeCheckingMode "off" ;; Disable heavy type checking for speed
					       :inlayHints (:variableTypes nil
									   :functionReturnTypes nil
									   :callArgumentNames nil)))))
    (pet-mode 1)
    (eglot-ensure))
  
  (add-hook 'python-mode-hook #'python-eglot-configs)
  (add-hook 'python-ts-mode-hook #'python-eglot-configs))

(use-package pet)

(use-package flymake-ruff
  :ensure t
  :hook (eglot-managed-mode . flymake-ruff-load))

(use-package uv
  :ensure (uv :type git :host github :repo "johannes-mueller/uv.el")
  :after tomlparse
  :init
  (add-to-list 'treesit-language-source-alist '(toml "https://github.com/tree-sitter-grammars/tree-sitter-toml"))
  (unless (treesit-language-available-p 'toml)
    (treesit-install-language-grammar 'toml)))

(use-package tomlparse
  :ensure (:type git :host github :repo "johannes-mueller/tomlparse.el"))

(with-eval-after-load 'apheleia
  (setf (alist-get 'ruff apheleia-formatters)
        '("ruff" "format" "--silent" "--stdin-filename" filepath "-"))
  (setf (alist-get 'ruff-isort apheleia-formatters)
        '("ruff" "check" "--select" "I" "--fix" "--silent" "--stdin-filename" filepath "-"))
  ;; Chain: Sort imports first, then format
  (setf (alist-get 'python-mode apheleia-mode-alist)
        '(ruff-isort ruff))
  (setf (alist-get 'python-ts-mode apheleia-mode-alist)
        '(ruff-isort ruff)))

(with-eval-after-load 'eglot
  (with-eval-after-load 'pet
    (add-server python-ts-mode-mode "basedpyright" "--stdio")))

(with-eval-after-load 'dape
  (add-to-list 'dape-configs
	       `(python-debug
                 :description "Python (debugpy)"
                 modes (python-mode python-ts-mode)
                 command "python3"
                 command-args ("-m" "debugpy.adapter")
                 :type "executable"
                 :request "launch"
                 :cwd dape-cwd-fn
                 :program ,(or (buffer-file-name) "/tmp/fallback.py"))))

(provide 'os-python)
