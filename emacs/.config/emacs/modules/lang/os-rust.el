;;; os-rust.el --- Rust configuration -*- lexical-binding: t; -*-

(use-package rust-mode) ;; Rust
(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode))
(add-hook 'rust-ts-mode-hook #'eglot-ensure)
(use-package cargo-mode
  :defer t
  :hook
  (rust-ts-mode . cargo-minor-mode)
  :config
  (setq compilation-scroll-output t))

(with-eval-after-load 'apheleia
  (setf (alist-get 'rustfmt apheleia-formatters)
        '("rustfmt" "--quiet" "--emit" "stdout"))
  (setf (alist-get 'rust-mode apheleia-mode-alist) 'rustfmt)
  (setf (alist-get 'rust-ts-mode apheleia-mode-alist) 'rustfmt)
  (setf (alist-get 'rustic-mode apheleia-mode-alist) 'rustfmt))

(with-eval-after-load 'dape
  (add-to-list 'dape-configs
               `(rust-gdb
                 :description "Rust (GDB)"
                 modes (rust-mode rust-ts-mode)
                 command "gdb"
                 command-args ("--interpreter=mi2" "--args")
                 :type "gdb"
                 :request "launch"
                 :cwd dape-cwd-fn
                 :program ,(expand-file-name "target/debug/mi_crate"))))

(provide 'os-rust)
