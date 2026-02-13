;;; os-toml.el --- TOML configuration -*- lexical-binding: t; -*-

(require 'os-macros)

(use-package toml-ts-mode
  :ensure nil
  :mode "\\.toml\\'")

(provide 'os-toml)
