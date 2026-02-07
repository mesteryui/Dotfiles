;;; os-lua.el --- Lua configuration -*- lexical-binding: t; -*-

(use-package lua-mode
  :ensure t
  :custom
  (lua-indent-level 4)
  :config
  (setq lua-indent-string-contents t)
  ;; Ensure .lua files use the correct mode
  (add-to-list 'auto-mode-alist '("\.lua\'" . lua-mode)))

;; Modern Tree-sitter mode for Lua (better highlighting)
(use-package lua-ts-mode
  :ensure nil
  :mode "\.lua\'"
  :hook (lua-ts-mode . eglot-ensure)
  :config
  ;; Tell Eglot to use lua-language-server
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(lua-ts-mode . ("lua-language-server")))))

;; Formatting with Stylua (install via: cargo install stylua or pacman -S stylua)
(with-eval-after-load 'apheleia
  (setf (alist-get 'stylua apheleia-formatters) 
        '("stylua" "-"))
  (setf (alist-get 'lua-mode apheleia-mode-alist) 'stylua)
  (setf (alist-get 'lua-ts-mode apheleia-mode-alist) 'stylua))

;; Specific Eglot configuration for Lua to recognize globals (menus/awesome/etc)
(defun os/lua-eglot-init ()
  (setq-local eglot-workspace-configuration
              '(:Lua (:diagnostics (:globals ["vim" "awesome" "client" "root" "love"])))))

(add-hook 'lua-mode-hook #'os/lua-eglot-init)
(add-hook 'lua-ts-mode-hook #'os/lua-eglot-init)

(provide 'os-lua)
