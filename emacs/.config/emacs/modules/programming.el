;; -*- lexical-binding: t; -*-
(add-hook 'prog-mode-hook 'display-line-numbers-mode)
(setopt display-line-numbers-type 'relative)
(setq-default display-fill-column-indicator-column 79)
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)

(use-package outline
  :ensure nil
  :commands outline-minor-mode
  :hook
  ((emacs-lisp-mode . outline-minor-mode)
   ;; Use " ▼" instead of the default ellipsis "..." for folded text to make
   ;; folds more visually distinctive and readable.
   (outline-minor-mode
    .
    (lambda()
      (let* ((display-table (or buffer-display-table (make-display-table)))
             (face-offset (* (face-id 'shadow) (ash 1 22)))
             (value (vconcat (mapcar (lambda (c) (+ face-offset c)) " ▼"))))
        (set-display-table-slot display-table 'selective-display value)
        (setq buffer-display-table display-table))))))
(gbind "C-<tab>" outline-cycle)
(use-package outline-indent
  :ensure t
  :commands outline-indent-minor-mode
  ;;  :bind (:map outline-indent-minor-mode-map ("TAB" . outline-indent-toggle-fold))
  :custom
  (outline-indent-ellipsis " ▼")
  :init
  ;; The minor mode can also be automatically activated for a certain modes.
  (add-hook 'python-mode-hook #'outline-indent-minor-mode)
  (add-hook 'python-ts-mode-hook #'outline-indent-minor-mode)

  (add-hook 'yaml-mode-hook #'outline-indent-minor-mode)
  (add-hook 'yaml-ts-mode-hook #'outline-indent-minor-mode))

(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :config
  (defun my-ef-themes-hl-todo-faces ()
    "Configure `hl-todo-keyword-faces' with Ef themes colors.
The exact color values are taken from the active Ef theme."
    (ef-themes-with-colors
      (setq hl-todo-keyword-faces
            `(("HOLD" . ,yellow)
              ("TODO" . ,red)
              ("NEXT" . ,blue)
              ("THEM" . ,magenta)
              ("PROG" . ,cyan-warmer)
              ("OKAY" . ,green-warmer)
              ("DONT" . ,yellow-warmer)
              ("FAIL" . ,red-warmer)
              ("BUG" . ,red-warmer)
              ("DONE" . ,green)
              ("NOTE" . ,blue-warmer)
              ("KLUDGE" . ,cyan)
              ("HACK" . ,cyan)
              ("TEMP" . ,red)
              ("FIXME" . ,red-warmer)
              ("XXX+" . ,red-warmer)
              ("REVIEW" . ,red)
              ("DEPRECATED" . ,yellow)))))
  (add-hook 'ef-themes-post-load-hook #'my-ef-themes-hl-todo-faces))

(use-package transient)

(use-package eldoc-box
  :ensure t
  :defer t)

(use-package apheleia
  :ensure t
  :defer t
  :diminish apheleia-mode
  :hook
  ((prog-mode . apheleia-mode)   ;; enable in all programming modes
   (text-mode . apheleia-mode)) ;; optional, formats Markdown, etc.
  :custom
  ;; Respect Emacs indentation settings
  (apheleia-formatters-respect-indent-level t)
  ;; Hide log buffers from buffer list
  (apheleia-hide-log-buffers t)
  ;; Only log errors
  (apheleia-log-only-errors t)
  ;; Remote file formatting
  (apheleia-remote-algorithm 'local)
  :config
  ;; Example formatters setup
  (setf (alist-get 'clang-format apheleia-formatters)
        '("clang-format" "-style=Google"))
  (setf (alist-get 'prettier apheleia-formatters)
        '("prettier" "--stdin-filepath" filepath))
  (setf (alist-get 'ruff apheleia-formatters)
        '("ruff" "format" "--silent" "--stdin-filename" filepath "-"))
  (setf (alist-get 'ruff-isort apheleia-formatters)
        '("ruff" "check" "--select" "I" "--fix" "--silent" "--stdin-filename" filepath "-"))
  ;; Language → formatter mapping
  (setf (alist-get 'rustfmt apheleia-formatters)
        '("rustfmt" "--quiet" "--emit" "stdout"))
  (setf (alist-get 'rust-mode apheleia-mode-alist) 'rustfmt)
  (setf (alist-get 'rust-ts-mode apheleia-mode-alist) 'rustfmt)
  (setf (alist-get 'rustic-mode apheleia-mode-alist) 'rustfmt)
  (setf (alist-get 'c-mode apheleia-mode-alist) 'clang-format)
  (setf (alist-get 'c++-mode apheleia-mode-alist) 'clang-format)
  (setf (alist-get 'js-mode apheleia-mode-alist) 'prettier)
  (setf (alist-get 'json-mode apheleia-mode-alist) 'prettier)
  (setf (alist-get 'css-mode apheleia-mode-alist) 'prettier)
  (setf (alist-get 'html-mode apheleia-mode-alist) 'prettier)
  (setf (alist-get 'python-mode apheleia-mode-alist)
	'(ruff-isort ruff))
  (setf (alist-get 'python-ts-mode apheleia-mode-alist)
	'(ruff-isort ruff)))

(use-package eglot
  :ensure nil
  :commands (eglot-ensure eglor-rename eglot-format-buffer)
  :hook (eglot-managed-mode . eldoc-box-hover-mode)
  :config
  (setq-default eglot-workspace-configuration
		'((:pyright (:disableOrganizeImports nil
						     :typeCheckingMode "basic"))
		  (:gopls .
			  ((staticcheck . t)
			   (matcher . "CaseSensitive")))))              
  :custom
  (eglot-sync-connect nil)
  (eglot-autoshutdown t)
  (eglot-events-buffer-size 0)
  (eglot-auto-display-help-buffer nil)
  (eglot-confirm-server-initiated-edits nil)
  (eglot-extend-to-xref t)
  (eglot-send-changes-idle-time 0.1)
  :bind (:map eglot-mode-map
	      ("C-c l a" . eglot-code-actions)
	      ("C-c l i" . eglot-code-actions-organize-imports)
	      ("C-c l r" . eglot-rename)
	      ("C-c l f" . eglot-format)
	      ("C-c l n" . flymake-next-error)
	      ("C-c l p" . flymake-previous-error)
	      ("C-c l d" . eldoc))
  :config
  (add-to-list 'eglot-server-programs
	       `(python-ts-mode
		 . ,(eglot-alternatives '(("pyright-langserver" "--stdio")
					  "jedi-language-server"
					  "pylsp"))))
  (add-to-list 'eglot-server-programs '((hyprlang-ts-mode) . ("hyprls")))
  ;; (add-to-list 'eglot-server-programs
  ;;              '((python-mode python-ts-mode) . ("pylsp")))
  ;; (add-to-list 'eglot-server-programs
  ;;              '((c-mode c++-mode) . ("clangd")))
  )

(use-package dape
  :defer t
  :custom
  (dape-buffer-window-arrangement 'gud)
  (dape-use-icons t)
  (dape-request-timeout 30)
  (dape-inlay-hints t)
  :config
  ;; Configuración para Python con debugpy
  (add-to-list 'dape-configs
	       `(python-debug
                 :description "Python (debugpy)"
                 modes (python-mode python-ts-mode)
                 command "python3"
                 command-args ("-m" "debugpy.adapter")
                 :type "executable"            ; usar "executable" para debugpy
                 :request "launch"
                 :cwd dape-cwd-fn
                 :program ,(or (buffer-file-name) "/tmp/fallback.py")))  ;; apunta al buffer actual
  ;; Configuración para Rust con GDB
  (add-to-list 'dape-configs
	       `(rust-gdb
                 :description "Rust (GDB)"
                 modes (rust-mode rust-ts-mode)
                 command "gdb"
                 command-args ("--interpreter=mi2" "--args")
                 :type "gdb"
                 :request "launch"
                 :cwd dape-cwd-fn
                 :program ,(expand-file-name "target/debug/mi_crate"))))

(use-package projectile
  :ensure t
  :config
  (projectile-mode +1))

(setopt projectile-project-root-files '(".git"))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package rainbow-mode
  :defer t
  :hook ((org-mode . rainbow-mode) (prog-mode . rainbow-mode)))

(use-package flymake
  :ensure t
  :defer t
  :hook
  (prog-mode . flymake-mode)
  :config 
  (setopt flymake-fringe-indicator-position 'left-fringe)
  (setopt flymake-show-diagnostics-at-end-of-line nil)

  ;; Suppress the display of Flymake error counters when there are no errors.
  (setopt flymake-suppress-zero-counters t)

  ;; Disable wrapping around when navigating Flymake errors.
  (setopt flymake-wrap-around nil))

(use-package flymake-flycheck
  :ensure t
  :defer t
  :hook
  (flymake-mode-hook . flymake-flycheck-auto))
(with-eval-after-load 'flymake-mode
  (define-key flymake-mode-map (kbd "M-n") #'flymake-goto-next-error))

(provide 'programming)
