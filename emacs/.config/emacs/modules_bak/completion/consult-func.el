;; -*- lexical-binding: t; -*- 
(use-package consult
  :after (orderless)
  :hook (completion-list-mode . consult-preview-at-point-mode)
  :init 
  (setq register-preview-delay 0.5
	register-preview-function #'consult-register-format)
  (setq xref-show-xrefs-function #'consult-xref
	xref-show-definitions-function #'consult-xref)
  :config
  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-ripgrep consult-git-grep consult-grep
   consult-bookmark consult-recent-file consult-xref
   consult--source-bookmark consult--source-file-register
   consult--source-recent-file consult--source-project-recent-file
   ;; :preview-key "M-."
   :preview-key '(:debounce 0.4 any))
  (setq consult-narrow-key "<")
  :bind (
	 ("C-c M-x" . consult-mode-command)
	 ("C-x b" . consult-buffer)                ;; orig. switch-to-buffer
	 ("C-x r b" . consult-bookmark)            ;; orig. bookmark-jump
	 ("M-y" . consult-yank-pop)                ;; orig. yank-pop
	 ("M-g o" . consult-outline)               ;; Alternativa: consult-org-heading
	 ("M-g i" . consult-imenu)
	 ("M-g I" . consult-imenu-multi)
	 ("M-s d" . consult-find)                  ;; Alternativa: consult-fd
	 ("M-s g" . consult-grep)
	 ("C-s" . consult-line)))

(provide 'consult-func)
;;; consult-func.el ends here
