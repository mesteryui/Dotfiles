;; -*- lexical-binding: t; -*-

(defmacro add-server (mode server &rest args)
  "Añadir un servidor lsp personalizado definido como SERVER a un modo MODE especifico con ARGS opcionales si se requieren"
  `(with-eval-after-load 'eglot
     (add-to-list 'eglot-server-programs '(,mode . (,server ,@args)))))

(use-package eglot
  :ensure nil
  :after mason
  :hook
  (eglot-managed-mode . eldoc-mode)
  ;;(eglot-managed-mode . eldoc-box-hover-mode)
  :custom
  (eglot-confirm-server-initiated-edits nil)
  (eglot-sync-connect nil)
  (eglot-autoshutdown t)
  (eglot-ignored-server-capabilities '(:documentHighlightProvider))
  (eglot-events-buffer-size 0)
  (eglot-autoshutdown t)
  ;;(eglot-connect-timeout 60)
  (eglot-send-changes-idle-time 0.5)
  (eglot-auto-display-help-buffer nil)
  (eglot-confirm-server-initiated-edits nil)
  (eglot-extend-to-xref t)
  :bind (:map eglot-mode-map
	      ("C-c l a" . eglot-code-actions)
	      ("C-c l i" . eglot-code-actions-organize-imports)
	      ("C-c l r" . eglot-rename)
	      ("C-c l f" . eglot-format)
	      ("C-c l n" . flymake-next-error)
	      ("C-c l p" . flymake-previous-error)
	      ("C-c l d" . eldoc))
  :config
  (setq jsonrpc-default-request-timeout 5)
  (with-eval-after-load 'jsonrpc
    (fset #'jsonrpc--log-event #'ignore)))

(use-package eglot-tempel
  :preface (eglot-tempel-mode)
  :init
  (eglot-tempel-mode t))


(provide 'lsp-confs)
;;; lsp-confs.el ends here
