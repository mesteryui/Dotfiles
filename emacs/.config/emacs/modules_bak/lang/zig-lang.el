;; -*- lexical-binding: t; -*- 

(use-package zig-mode
  :ensure t
  :mode ("\\.zig\\'" . zig-mode)
  :hook (zig-mode . eglot-ensure)
  :custom
  (zig-format-on-save nil))
(provide 'zig-lang)
;;; zig-lang.el ends here

