;;; os-lsp-confs.el --- Eglot High Performance configuration -*- lexical-binding: t -*-

;;; Code:
(defmacro add-server (modes server &rest args)
  "Añade un servidor LSP de forma segura, compatible con Mason."
  `(with-eval-after-load 'eglot
     (add-to-list 'eglot-server-programs
                  (cons ',modes 
                        (if (null ',args)
                            ,server  ; Si no hay argumentos, pasamos solo el comando
                          (append (list ,server) ',args))))))

(use-package eglot
  :ensure nil
  :custom
  (eglot-sync-connect 1)
  (eglot-connect-timeout 30)
  (eglot-autoshutdown nil)
  (eglot-send-changes-idle-time 0.5) ; Un poco más de margen para track-changes
  (eglot-auto-display-help-buffer nil)
  (eglot-report-progress nil)
  :config
  ;; Desactivar logs innecesarios para ganar rendimiento
  (fset #'jsonrpc--log-event #'ignore)
  
  ;; CAPF INTELIGENTE
  (setq completion-category-overrides '((eglot (styles orderless))
					(eglot-capf (styles orderless))))
  
  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              ;; Limpiar CAPF para evitar acumulaciones si eglot reinicia
              (setq-local completion-at-point-functions
                          (list (cape-capf-super
                                 #'eglot-completion-at-point
                                 #'tempel-expand
                                 #'cape-file)
                                #'cape-dabbrev)))))

(use-package eglot-tempel
  :ensure t
  :after (eglot tempel)
  :hook (eglot-managed-mode . eglot-tempel-mode))

(provide 'os-lsp-confs)
