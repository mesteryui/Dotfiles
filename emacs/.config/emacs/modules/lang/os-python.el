;;; os-python.el --- Python performance & full config -*- lexical-binding: t; -*-

;;; Code:

(use-package python
  :ensure nil
  :custom
  (python-indent-guess-indent-offset nil)
  :config
  (setq python-indent-offset 4)
  (defun python-eglot-configs ()
    "Aplicar configuraciones de python especificas para eglot."
    (pet-mode 1)
    (setq-local eglot-workspace-configuration
		'(:basedpyright (:analysis (:typeCheckingMode "basic"
							      :autoImportCompletions t
							      :autoSearchPaths t
							      :useLibraryCodeForTypes t
							      :exclude ["**/__pycache__"]))))
    (eglot-ensure))
  (add-hook 'python-ts-mode-hook #'python-eglot-configs))

(use-package pet
  :ensure t
  :config
  (setq pet-find-file-functions '(pet-find-file-from-project-root
                                  pet-locate-dominating-file)))

(use-package flymake-ruff
  :ensure t
  :hook (eglot-managed-mode . flymake-ruff-load))

;; Gestión de paquetes Python (uv)
(use-package uv
  :ensure (uv :type git :host github :repo "johannes-mueller/uv.el")
  :after tomlparse
  :init
  (add-to-list 'treesit-language-source-alist '(toml "https://github.com/tree-sitter-grammars/tree-sitter-toml"))
  (unless (treesit-language-available-p 'toml)
    (treesit-install-language-grammar 'toml)))

(use-package tomlparse
  :ensure (:type git :host github :repo "johannes-mueller/tomlparse.el"))

;; Formateo con Apheleia y Ruff
(with-eval-after-load 'apheleia
  (setf (alist-get 'ruff-combo apheleia-formatters)
        '("ruff" "check" "--select" "I" "--fix" "--silent" "--stdin-filename" filepath "-"))
  (setf (alist-get 'python-ts-mode apheleia-mode-alist) '(ruff-combo ruff))
  (setf (alist-get 'python-mode apheleia-mode-alist) '(ruff-combo ruff)))

;; USO IDIOMÁTICO DE LA CONFIGURACIÓN: Registrar el servidor mediante la macro add-server
(add-server (python-mode python-ts-mode) "basedpyright-langserver" "--stdio")

;; Ajustes adicionales para Eglot en Python
(with-eval-after-load 'eglot
  (add-to-list 'eglot-stay-out-of 'font-lock))

(with-eval-after-load 'dape
  (setf (alist-get 'python-pet dape-configs)
        '((python-mode python-ts-mode)
          command "python3" ;; Dejamos que el PATH del venv haga el trabajo
          command-args ("-m" "debugpy.adapter")
          :type "executable"
          :request "launch"
          :cwd dape-cwd-fn
          :program dape-buffer-default
          :autoport t)))

(provide 'os-python)
