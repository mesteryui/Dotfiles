;;; os-editing.el --- Editing tools and configuration -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: editing, tools

;;; Commentary:
;; Configuration for editing tools, history persistence, and clipboard.

;;; Code:

;; History persistence
(use-package savehist
  :ensure nil ; Built-in
  :init
  (savehist-mode 1)
  :custom
  (savehist-additional-variables '(kill-ring 
                                   search-ring 
                                   regexp-search-ring 
                                   last-kbd-macro)))

;; Clipboard and Kill-ring optimization
(setq select-enable-clipboard t              ;; Use system clipboard
      select-enable-primary t                ;; Use primary selection (middle click)
      save-interprogram-paste-before-kill t  ;; Save existing clipboard to kill-ring before overwriting
      kill-ring-max 300                      ;; History size
      kill-do-not-save-duplicates t)         ;; Don't save duplicates

;; Undo visualization and limits
(use-package vundo
  :ensure t
  :bind ("C-x u" . vundo)
  :config
  (setq vundo-glyph-alist vundo-unicode-symbols
        vundo-compact-display t))

(setq undo-limit 800000           ;; default: ~160k
      undo-strong-limit 12000000  ;; default: ~12MB
      undo-outer-limit 120000000) ;; default: ~120MB

(provide 'os-editing)
;;; os-editing.el ends here