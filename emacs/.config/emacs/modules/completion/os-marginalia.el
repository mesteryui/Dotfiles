;;; os-marginalia.el --- Marginalia configuration -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: completion, help

;;; Commentary:
;; Configuration for Marginalia (rich annotations in minibuffer).

;;; Code:

(use-package marginalia
  :commands (marginalia-mode marginalia-cycle)
  :custom
  (marginalia-annotators
   '(marginalia-annotators-heavy marginalia-annotators-lv))
  :init
  (marginalia-mode))

(use-package nerd-icons-completion
  :ensure t
  :after (marginalia nerd-icons)
  :hook (marginalia-mode . nerd-icons-completion-marginalia-setup)
  :init (nerd-icons-completion-mode))

(provide 'os-marginalia)
;;; os-marginalia.el ends here
