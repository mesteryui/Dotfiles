;;; -*- lexical-binding: t -*-
(use-package marginalia
  :ensure t
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
