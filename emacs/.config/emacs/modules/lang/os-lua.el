;;; os-lua.el --- Lua configuration -*- lexical-binding: t; -*-

(defun os/lua-eglot-init ()
  (setq-local eglot-workspace-configuration
              '(:Lua (:diagnostics (:globals ["vim" "awesome" "client" "root" "love"]))))
  (eglot-ensure))

(use-package lua-mode
  :ensure t
  :custom
  (lua-indent-level 4)
  :config
  (setq lua-indent-string-contents t)
  ;; Ensure .lua files use the correct mode
  (add-to-list 'auto-mode-alist '("\\.lua\\'" . lua-mode)))

;; Modern Tree-sitter mode for Lua (better highlighting)
(use-package lua-ts-mode
  :ensure nil
  :mode "\\.lua\\'"
  :hook (lua-ts-mode . os/lua-eglot-init)
  :config
  ;; Tell Eglot to use lua-language-server
  )

;; Formatting with Stylua (install via: cargo install stylua or pacman -S stylua)
(with-eval-after-load 'apheleia
  (setf (alist-get 'stylua apheleia-formatters) 
        '("stylua" "-"))
  (setf (alist-get 'lua-mode apheleia-mode-alist) 'stylua)
  (setf (alist-get 'lua-ts-mode apheleia-mode-alist) 'stylua))

;; Specific Eglot configuration for Lua to recognize globals (menus/awesome/etc)


(provide 'os-lua)
