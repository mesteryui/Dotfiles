;; -*- lexical-binding: t; -*-
;;  (use-package lsp-java :config (add-hook 'java-mode-hook 'lsp))
  (use-package eglot-java
    :defer t)
;; TODO Do the java programation more useful
 (add-hook 'java-mode-hook #'eglot-ensure)
 (add-hook 'java-mode-hook #'eglot-java-mode)

 (os/after eglot-java
    (define-key eglot-java-mode-map (kbd "C-c l n") #'eglot-java-file-new)
    (define-key eglot-java-mode-map (kbd "C-c l x") #'eglot-java-run-main)
    (define-key eglot-java-mode-map (kbd "C-c l t") #'eglot-java-run-test)
    (define-key eglot-java-mode-map (kbd "C-c l N") #'eglot-java-project-new)
    (define-key eglot-java-mode-map (kbd "C-c l T") #'eglot-java-project-build-task)
    (define-key eglot-java-mode-map (kbd "C-c l R") #'eglot-java-project-build-refresh))
  (use-package flymake-gradle
    :defer t)
(provide 'java)
