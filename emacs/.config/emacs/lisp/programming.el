(add-hook 'prog-mode-hook 'display-line-numbers-mode)
(setopt display-line-numbers-type 'relative)
(setq-default display-fill-column-indicator-column 79)
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)

(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :config
  (setq hl-todo-keyword-faces
    '(("FIXME" error bold)
      ("TODO" org-todo)
      ("DONE" org-done)
      ("NOTE" bold))))

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

(use-package kind-icon
  :after corfu
  :custom (kind-icon-default-face 'corfu-default)
  :config
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

(use-package tempel
  :bind (("M-+" . tempel-complete) ;; o el keybinding que prefieras
         ("M-*" . tempel-insert))
  :custom
  (tempel-path "~/.config/emacs/templates.el") ;; o donde quieras tus plantillas
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
  (add-hook 'conf-mode-hook 'tempel-setup-capf)
  (add-hook 'prog-mode-hook 'tempel-setup-capf)
  (add-hook 'text-mode-hook 'tempel-setup-capf)
  (add-hook 'org-mode-hook 'tempel-setup-capf)
  (add-hook 'eglot-managed-mode-hook 'tempel-setup-capf)
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
  :init (setq completion-category-overrides '((eglot (styles orderless))))
  :hook ((prog-mode . eglot-ensure)
         (eglot-managed-mode . eldoc-box-hover-mode))
  :custom
  (eglot-sync-connect 1)
  (eglot-autoshutdown t)
  (eglot-events-buffer-size 0)
  (eglot-auto-display-help-buffer nil)
  (eglot-confirm-server-initiated-edits nil)
  :bind (:map eglot-mode-map
              ("C-c l a" . eglot-code-actions)
              ("C-c l i" . eglot-code-actions-organize-imports)
              ("C-c l r" . eglot-rename)
              ("C-c l f" . eglot-format)
              ("C-c l n" . flymake-next-error)
              ("C-c l p" . flymake-previous-error)
              ("C-c l d" . eldoc))
  :config
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

;; (use-package treesit-auto
;;   :config
;;   (global-treesit-auto-mode))
(setq-default treesit-extra-load-path (list (no-littering-expand-var-file-name "tree-sitter/")))
 (setq treesit-language-source-alist
      '((bash "https://github.com/tree-sitter/tree-sitter-bash")
        (c "https://github.com/tree-sitter/tree-sitter-c")
        (css "https://github.com/tree-sitter/tree-sitter-css")
        (html "https://github.com/tree-sitter/tree-sitter-html")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript")
        (json "https://github.com/tree-sitter/tree-sitter-json")
        (lua "https://github.com/Azganoth/tree-sitter-lua")
        (php "https://github.com/tree-sitter/tree-sitter-php")
        (python "https://github.com/tree-sitter/tree-sitter-python")
        (ruby "https://github.com/tree-sitter/tree-sitter-ruby")
        (rust "https://github.com/tree-sitter/tree-sitter-rust")
        (toml "https://github.com/tree-sitter/tree-sitter-toml")
        (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
        (yaml "https://github.com/ikatyang/tree-sitter-yaml")
        (kdl "https://github.com/tree-sitter-grammars/tree-sitter-kdl")))
(add-to-list 'treesit-language-source-alist
        '(hyprlang "https://github.com/tree-sitter-grammars/tree-sitter-hyprlang"))
(setopt treesit-font-lock-level 4)  ;; Maximum highlighting
     (setopt major-mode-remap-alist
        '((c-mode . c-ts-mode)
          (css-mode . css-ts-mode)
          (js-mode . js-ts-mode)
          (javascript-mode . js-ts-mode)
          (js2-mode . js-ts-mode)
          (typescript-mode . typescript-ts-mode)
          (json-mode . json-ts-mode)
          (python-mode . python-ts-mode)
          (bash-mode . bash-ts-mode)
          (sh-mode . bash-ts-mode)
          (yaml-mode . yaml-ts-mode)
          (rust-mode . rust-ts-mode)
          (lua-mode . lua-ts-mode)))

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

(use-package flyover
:ensure (flyover :type git :host github :repo "konrad1977/flyover")
:hook (flymake-mode . flyover-mode)
:config 
(setq flyover-levels '(error warning info))  ; Show all levels

)

(provide 'programming)
