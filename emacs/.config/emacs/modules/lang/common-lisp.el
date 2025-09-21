;; -*- lexical-binding: t; -*-
  (use-package sly
    :ensure t
    :commands sly
    :config
    (setq inferior-lisp-program "/usr/bin/sbcl"))
(provide 'common-lisp)
