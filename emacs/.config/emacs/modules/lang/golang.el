;; -*- lexical-binding: t; -*-

(use-package go-ts-mode
  :ensure nil)
(add-hook 'go-ts-mode-hook #'eglot-ensure)

(provide 'golang)
