;;; os-zig.el --- Zig configuration -*- lexical-binding: t; -*-

(use-package zig-mode
  :ensure t
  :mode ("\.zig\'" . zig-mode)
  :hook (zig-mode . eglot-ensure)
  :custom
  (zig-format-on-save nil))

(provide 'os-zig)

