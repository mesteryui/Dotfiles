;;; -*- lexical-binding: t -*-

(use-package nerd-icons
  :ensure t)

(use-package nerd-icons-dired
  :ensure t
  :after (nerd-icons dired)
  :hook
  (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-corfu
  :ensure t
  :after (corfu nerd-icons)
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

(use-package nerd-icons-xref
  :ensure t
  :if (display-graphic-p)
  :after (xref corfu)
  :config
  (nerd-icons-xref-mode 1))

(provide 'os-icons)
