;;; os-config-modes.el --- Config modes configuration -*- lexical-binding: t; -*-

(use-package fish-mode
  :ensure t)

(use-package yuck-mode :ensure t)

(use-package i3wm-config-mode
  :ensure t
  :mode
  ("/sway/.*config.*/" . i3wm-config-mode)
  ("/sway/config'" . i3wm-config-mode))

(provide 'os-config-modes)
