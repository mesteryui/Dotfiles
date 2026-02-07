;;; -*- lexical-binding: t -*-

(use-package eat
  :ensure t
  :init 
  (setq eat-shell "/usr/bin/fish")
  (setq eat-term-maximum-scrollback 10000))

(provide 'os-eat)
