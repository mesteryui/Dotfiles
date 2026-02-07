;;; os-editing.el --- Editing tools and configuration -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: editing, tools

;;; Commentary:
;; Configuration for editing tools like Vundo (undo tree visualization).

;;; Code:


(use-package vundo
  :ensure t
  :bind ("C-x u" . vundo)
  :config
  (setq vundo-glyph-alist vundo-unicode-symbols
        vundo-compact-display t))

;; Undo limits
(setq undo-limit 800000           ;; default: ~160k
      undo-strong-limit 12000000  ;; default: ~12MB
      undo-outer-limit 120000000) ;; default: ~120MB

(provide 'os-editing)
;;; os-editing.el ends here
