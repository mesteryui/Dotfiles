;;; misc.el --- Miscellaneous Configurations -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: misc

;;; Commentary:
;; Miscellaneous packages that didn't fit into other categories,
;; including scratch buffer config, savehist, autorevert, etc.

;;; Code:

(use-package os-scratch
  :load-path "os-lisp/"
  :config
  (add-to-list 'os-scratch-messages `(text . ,(format "Welcome to text-mode %s." user-full-name))))

(use-package ace-window
  :ensure t
  :defer t
  :init
  (global-set-key [remap other-window] 'ace-window)
  (custom-set-faces
   '(aw-leading-char-face
     ((t (:inherit ace-jump-face-foreground :height 3.0))))))

(use-package autorevert
  :ensure nil
  :diminish
  :hook (after-init . global-auto-revert-mode))

(use-package savehist
  :ensure nil
  :hook (after-init . savehist-mode))

(use-package ledger-mode
  :ensure t)

(use-package jsonrpc
  :ensure t)

;; Dictionary Defaults
(setopt dictionary-use-single-buffer t)
(setopt dictionary-server "dict.org")

(provide 'misc)
;;; misc.el ends here
