;; -*- lexical-binding: t; -*-
(use-package rust-mode) ;; Rust

(use-package cargo-mode
    :defer t
    :hook
    (rust-ts-mode . cargo-minor-mode)    
    :config
    (setq compilation-scroll-output t))
(provide 'rust)
