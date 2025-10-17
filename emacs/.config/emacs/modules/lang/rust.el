;; -*- lexical-binding: t; -*-
(use-package rust-mode) ;; Rust
(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode))
(add-hook 'rust-ts-mode-hook #'eglot-ensure)
(use-package cargo-mode
    :defer t
    :hook
    (rust-ts-mode . cargo-minor-mode)    
    :config
    (setq compilation-scroll-output t))
(provide 'rust)
