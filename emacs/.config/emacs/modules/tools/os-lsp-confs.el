;;; os-lsp-confs.el --- Eglot High Performance configuration -*- lexical-binding: t -*-

;;; Code:

(defmacro add-server (mode server &rest args)
  "Añadir un servidor lsp personalizado."
  `(with-eval-after-load 'eglot
     (add-to-list 'eglot-server-programs '(,mode . (,server ,@args)))))

(use-package eglot
  :ensure nil
  :hook (eglot-managed-mode . eldoc-mode)
  :custom
  ;; RENDIMIENTO Y ESTABILIDAD
  (eglot-confirm-server-initiated-edits t)
  (eglot-sync-connect nil)
  (eglot-autoreconnect 3)
  (eglot-autoshutdown nil) ; Mantener vivo el server aunque cerremos buffers (más estable)
  (eglot-ignored-server-capabilities '(:documentHighlightProvider))
  (eglot-connect-timeout 60)    ; Dar tiempo a servers pesados (Java/Rust)
  (eglot-send-changes-idle-time 0.2)
  (eglot-extend-to-xref t)
  (eglot-report-progress t)       ; Ver qué está haciendo el server
  :config
  (fset 'jsonrpc-log-event #'ignore)
  ;; CAPF INTELIGENTE
  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              (setq-local completion-at-point-functions
                          (list (cape-capf-super
                                 (cape-capf-buster #'eglot-completion-at-point)
                                 #'tempel-expand
                                 #'cape-file)
                                #'cape-dabbrev))))

  ;; OPTIMIZACIÓN DE FLUJO DE DATOS
  (setq read-process-output-max (* 3 1024 1024))) ; 3MB de buffer de lectura

(use-package eglot-tempel
  :ensure t
  :after (eglot tempel)
  :hook (eglot-managed-mode . eglot-tempel-mode))

(provide 'os-lsp-confs)
