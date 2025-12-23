;;; -*- lexical-binding: t -*-

(use-package nerd-icons
  :ensure t)
(use-package nerd-icons-dired
  :ensure t
  :after (nerd-icons dired)
  :hook
  (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-xref
  :ensure t
  :if (display-graphic-p)
  :after xref
  :config
  (nerd-icons-xref-mode 1))

(provide 'nerd-icons-settings)
