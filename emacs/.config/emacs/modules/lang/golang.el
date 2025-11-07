;; -*- lexical-binding: t; -*-


(add-to-list 'auto-mode-alist '("\\.go\\'" . go-ts-mode))
(defun eglot-go-config ()
  (setq-local eglot-workspace-configuration
	      '(:gopls (:analyses (:unusedparams t)
				  :staticcheck t))))
(add-hook 'go-ts-mode #'eglot-go-config)
(add-hook 'go-ts-mode-hook #'eglot-ensure)

(provide 'golang)
