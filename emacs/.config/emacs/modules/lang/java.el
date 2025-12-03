;; -*- lexical-binding: t; -*-
;;  (use-package lsp-java :config (add-hook 'java-mode-hook 'lsp))
(use-package eglot-java
  :ensure t
  :defer t
  :custom
  (eglot-java-eclipse-jdt-args 
   '("-Xmx2G" "-XX:+UseG1GC" "-XX:+UseStringDeduplication"))
  (eglot-java-user-init-opts-fn 'eglot-java-init-opts))
;; TODO Do the java programation more useful
(add-hook 'java-mode-hook #'eglot-ensure)
(add-hook 'java-ts-mode #'eglot-ensure)
(add-hook 'java-mode-hook #'eglot-java-mode)
(add-hook 'java-ts-mode #'eglot-java-mode)
(os/after eglot-java
	  (define-key eglot-java-mode-map (kbd "C-c l n") #'eglot-java-file-new)
	  (define-key eglot-java-mode-map (kbd "C-c l x") #'eglot-java-run-main)
	  (define-key eglot-java-mode-map (kbd "C-c l t") #'eglot-java-run-test)
	  (define-key eglot-java-mode-map (kbd "C-c l N") #'eglot-java-project-new)
	  (define-key eglot-java-mode-map (kbd "C-c l T") #'eglot-java-project-build-task)
	  (define-key eglot-java-mode-map (kbd "C-c l R") #'eglot-java-project-build-refresh))
(use-package mvn
  :ensure t
  :defer t
  :bind (:map java-mode-map
              ("C-c m c" . mvn-clean)
              ("C-c m i" . mvn-install)
              ("C-c m t" . mvn-test)))

(use-package gradle-mode
  :ensure t
  :hook (java-mode . gradle-mode)
  :custom
  (gradle-use-gradlew t))
(use-package flymake-gradle
  :defer t)
(provide 'java)
