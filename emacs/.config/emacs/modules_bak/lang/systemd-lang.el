;; -*- lexical-binding: t; -*- 
(use-package systemd
  :mode ("\\.service\\'" . systemd-mode)
  :init
  (add-hook 'systemd-mode-hook #'display-line-numbers-mode))

(provide 'systemd-lang)
;;; systemd-lang.el ends here

