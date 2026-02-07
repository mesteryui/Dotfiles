;;; os-systemd.el --- Systemd configuration -*- lexical-binding: t; -*-

(use-package systemd
  :mode ("\.service\'" . systemd-mode)
  :init
  (add-hook 'systemd-mode-hook #'display-line-numbers-mode))

(provide 'os-systemd)

