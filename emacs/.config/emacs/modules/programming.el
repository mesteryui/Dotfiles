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
(use-package magit
   :bind
   ("C-x g" . magit-status))

(use-package magit-stats
  :ensure t)

 (use-package git-gutter
   :defer 0.3
   :delight
   :init (global-git-gutter-mode))

 (use-package git-timemachine
   :defer 1
   :delight)

(use-package eldoc-box
  :ensure t
  :defer t)

(use-package tempel
  :bind (("M-+" . tempel-complete) ;; o el keybinding que prefieras
         ("M-*" . tempel-insert))
  :custom
  (tempel-path "~/.config/emacs/templates.el") ;; o donde quieras tus plantillas
  :hook ((conf-mode prog-mode text-mode org-mode eglot-managed-mode) . tempel-setup-capf)
  :init
    (defun tempel-setup-capf ()
    ;; Add the Tempel Capf to `completion-at-point-functions'.
    ;; `tempel-expand' only triggers on exact matches. Alternatively use
    ;; `tempel-complete' if you want to see all matches, but then you
    ;; should also configure `tempel-trigger-prefix', such that Tempel
    ;; does not trigger too often when you don't expect it. NOTE: We add
    ;; `tempel-expand' *before* the main programming mode Capf, such
    ;; that it will be tried first.
    (setq-local completion-at-point-functions
                (cons #'tempel-expand (cons #'tempel-complete
                      completion-at-point-functions))))
;; (add-hook 'eglot-java-mode-hook 'tempel-setup-capf)
 ;; (add-hook 'lsp-mode-hook 'tempel-setup-capf)
 ;; (add-hook 'lsp-mode 'tempel-setup-capf)
 ;; (add-hook 'lsp-after-initialize-hook 'tempel-setup-capf)
 ;; (add-hook 'lsp-on-idle-hook 'tempel-setup-capf)
  :config 
   (define-key tempel-map (kbd "TAB") #'tempel-next))

(use-package tempel-collection :ensure t)

(use-package eglot
  :ensure nil
  :commands (eglot-ensure eglor-rename eglot-format-buffer)
  :hook (((python-ts-mode rust-ts-mode) . eglot-ensure)
         (eglot-managed-mode . eldoc-box-hover-mode))
  :config
  (setq-default eglot-workspace-configuration
              `(:pylsp (:plugins
                        (;; Fix imports and syntax using `eglot-format-buffer`
                         :isort (:enabled t)
                         :autopep8 (:enabled t)

                         ;; Syntax checkers (works with Flymake)
                         :pylint (:enabled t)
                         :pycodestyle (:enabled t)
                         :flake8 (:enabled t)
                         :pyflakes (:enabled t)
                         :pydocstyle (:enabled t)
                         :mccabe (:enabled t)

                         :yapf (:enabled :json-false)
                         :rope_autoimport (:enabled :json-false)))))
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
  (add-to-list 'eglot-server-programs '((hyprlang-ts-mode) . ("hyprls")))
  ;; (add-to-list 'eglot-server-programs
  ;;              '((python-mode python-ts-mode) . ("pylsp")))
  ;; (add-to-list 'eglot-server-programs
  ;;              '((c-mode c++-mode) . ("clangd")))
  )

(use-package iedit
  :ensure t)
(gbind "C-v" iedit-mode)

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

(setq treesit-extra-load-path (list (no-littering-expand-var-file-name "tree-sitter/")))
  (use-package treesit-auto
    :ensure t
    :custom
    (treesit-auto-install 'prompt)
    :config
    ;; (setq treesit-auto-langs (delete 'awk treesit-auto-langs))  ;; remove any grammar to avoid using ts-mode
    (treesit-auto-add-to-auto-mode-alist 'all)
    (global-treesit-auto-mode))

(setopt treesit-font-lock-level 4)  ;; Maximum highlighting

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
