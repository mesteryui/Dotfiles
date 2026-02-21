;;; os-java.el --- Java configuration -*- lexical-binding: t; -*-


;;  (use-package lsp-java :config (add-hook 'java-mode-hook 'lsp))
(use-package eglot-java
  :ensure t
  :after eglot
  :custom
  (eglot-java-eclipse-jdt-args '("-Xmx2G"
                                 "-XX:+UseG1GC"
                                 "-XX:+UseStringDeduplication"
                                 "--add-modules=ALL-SYSTEM"
                                 "--add-opens" "java.base/java.util=ALL-UNNAMED"
                                 "--add-opens" "java.base/java.lang=ALL-UNNAMED")))

;; Usar eglot-java-mode en lugar de eglot-ensure directamente para Java
;; eglot-java-mode se encarga de iniciar eglot con los argumentos correctos
(add-hook 'java-mode-hook #'eglot-java-mode)
(add-hook 'java-ts-mode-hook #'eglot-java-mode)

;; TODO Do the java programation more useful

(os/after eglot-java
          (define-key eglot-java-mode-map (kbd "C-c l n") #'eglot-java-file-new)
          (define-key eglot-java-mode-map (kbd "C-c l x") #'eglot-java-run-main)
          (define-key eglot-java-mode-map (kbd "C-c l t") #'eglot-java-run-test)
          (define-key eglot-java-mode-map (kbd "C-c l N") #'eglot-java-project-new)
          (define-key eglot-java-mode-map (kbd "C-c l T") #'eglot-java-project-build-task)
          (define-key eglot-java-mode-map (kbd "C-c l R") #'eglot-java-project-build-refresh)
          (define-key eglot-java-mode-map (kbd "C-c l C") #'os/java-clean-cache))

(defun os/java-clean-cache ()
  "Clean JDTLS cache."
  (interactive)
  (when (y-or-n-p "Really clean JDTLS cache? ")
    (let ((cache-dir (expand-file-name "eglot-java-eclipse-jdt-cache/" user-emacs-directory)))
      (if (file-exists-p cache-dir)
          (progn
            (delete-directory cache-dir t)
            (message "JDTLS cache cleaned. Please restart Emacs."))
        (message "Cache directory not found.")))))

(use-package flymake-gradle
  :defer t)

(provide 'os-java)
