(use-package pyvenv
  :ensure t)

(defun my/pyvenv-auto-activate ()
  "Si existe un entorno .venv en el proyecto, activarlo."
  (let ((root (locate-dominating-file default-directory ".venv")))
    (when root
      (pyvenv-activate (expand-file-name ".venv" root)))))

(add-hook 'python-mode-hook #'my/pyvenv-auto-activate)

;; Black

(add-hook 'python-mode-hook
          (lambda ()
            (add-hook 'before-save-hook 'black-format-buffer nil t)
            (add-hook 'before-save-hook 'isort-format-buffer nil t)))
(use-package flymake-ruff
  :ensure t
  :hook (python-mode . flymake-ruff-load))

;; -*- lexical-binding: t; -*-
(use-package uv
  :ensure (uv :type git :host github :repo "johannes-mueller/uv.el")
  :init
  (add-to-list 'treesit-language-source-alist '(toml "https://github.com/tree-sitter-grammars/tree-sitter-toml"))
  (unless (treesit-language-available-p 'toml)
    (treesit-install-language-grammar 'toml)))
(use-package tomlparse
  :ensure (:type git :host github :repo "johannes-mueller/tomlparse.el"))
(provide 'pythonlang)
