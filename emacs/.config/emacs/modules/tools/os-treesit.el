;;; -*- lexical-binding: t -*-

(os/after treesit
	  (add-to-list 'auto-mode-alist '("\\.jsonc\\'" . json-ts-mode))
	  (add-to-list 'treesit-language-source-alist '(json "https://github.com/tree-sitter/tree-sitter-json"))
	  (unless (treesit-language-available-p 'json)
	    (treesit-install-language-grammar 'json)))

(setq treesit-extra-load-path (list (no-littering-expand-var-file-name "tree-sitter/")))
(use-package treesit-auto
  :ensure t
  :custom
  (treesit-auto-install 'prompt)
  :config
  ;; (setq treesit-auto-langs (delete 'awk treesit-auto-langs))  ;; remove any grammar to avoid using ts-mode
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

(setopt treesit-font-lock-level 4)  ;; Maximum highlighting



(provide 'os-treesit)
