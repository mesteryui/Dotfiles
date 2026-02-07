;;; -*- lexical-binding: t -*-

;;(add-hook 'prog-mode-hook 'display-line-numbers-mode)
(global-display-line-numbers-mode)
(dolist (mode '(org-mode-hook
                cfw:calendar-mode-hook
                shell-mode-hook
                treemacs-mode-hook
                term-mode-hook
                vterm-mode-hook
                eat-mode-hook
                eshell-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))
(setopt display-line-numbers-type 'relative)
(setq-default display-fill-column-indicator-column 79)
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package rainbow-mode
  :defer t
  :hook ((org-mode . rainbow-mode) (prog-mode . rainbow-mode)))

;; Code Folding / Outlining
(use-package outline
  :ensure nil
  :hook
  ((prog-mode . outline-minor-mode)
   (prog-mode . hs-minor-mode)
   (outline-minor-mode
    .
    (lambda()
      (let* ((display-table (or buffer-display-table (make-display-table)))
             (face-offset (* (face-id 'shadow) (ash 1 22)))
             (value (vconcat (mapcar (lambda (c) (+ face-offset c)) " ▼"))))
        (set-display-table-slot display-table 'selective-display value)
        (setq buffer-display-table display-table))))))

(use-package bicycle
  :ensure t
  :after outline
  :bind (:map outline-minor-mode-map
              ("C-<tab>" . bicycle-cycle)
              ("S-<tab>" . bicycle-cycle-global)))

(use-package outline-indent
  :ensure t
  :commands outline-indent-minor-mode
  :custom
  (outline-indent-ellipsis " ▼")
  :init
  (add-hook 'python-mode-hook #'outline-indent-minor-mode)
  (add-hook 'python-ts-mode-hook #'outline-indent-minor-mode)
  (add-hook 'yaml-mode-hook #'outline-indent-minor-mode)
  (add-hook 'yaml-ts-mode-hook #'outline-indent-minor-mode))

;; TODO Highlights
(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :config
  (defun my-ef-themes-hl-todo-faces ()
    "Configure `hl-todo-keyword-faces' with Ef themes colors."
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

;; Project Management
(use-package projectile
  :ensure t
  :config
  (projectile-mode +1))
(setopt projectile-project-root-files '(".git"))

;;(use-package transient)

;; Formatting
(use-package apheleia
  :ensure t
  :after mason
  :diminish apheleia-mode
  :hook
  ((prog-mode . apheleia-mode)
   (text-mode . apheleia-mode))
  :custom
  (apheleia-formatters-respect-indent-level t)
  (apheleia-hide-log-buffers t)
  (apheleia-log-only-errors t)
  (apheleia-remote-algorithm 'local))

;; LSP / Tooling
(use-package mason
  :ensure t
  :config
  (mason-ensure))
(os/after mason
          (mason-ensure
           (lambda ()
             (ignore-errors (mason-install "basedpyright"))
             (ignore-errors (mason-install "jdtls"))
             (ignore-errors (mason-install "gopls")))))

(moon-loader-add-modules os-lsp-confs)

;; Debugging
(use-package dape
  :defer t
  :custom
  (dape-buffer-window-arrangement 'gud)
  (dape-use-icons t)
  (dape-request-timeout 30)
  (dape-inlay-hints t))

;; Linting / Diagnostics (Flymake)
(use-package flymake
  :ensure t
  :defer t
  :hook (prog-mode . flymake-mode)
  :config 
  (setopt flymake-fringe-indicator-position 'left-fringe)
  (setopt flymake-show-diagnostics-at-end-of-line nil)
  (setopt flymake-no-changes-timeout 1.0)
  (setopt flymake-suppress-zero-counters t)
  (setopt flymake-wrap-around nil))

(use-package flymake-flycheck
  :ensure t
  :defer t
  :hook (flymake-mode-hook . flymake-flycheck-auto))

(with-eval-after-load 'flymake-mode
  (define-key flymake-mode-map (kbd "M-n") #'flymake-goto-next-error))

(provide 'os-programming)
