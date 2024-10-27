;; Package -- Eglot setup
;; Comment:
;;

(use-package eldoc
    :defer t
    :after elpaca)
  (use-package eldoc-box
    :ensure t
    :defer t
    :after eldoc
    :init (setq eldoc-box-hover-mode t))
(use-package eglot
    :defer t
    :after elpaca)
  ;(add-hook 'compilation-mode-hook #'comint-mode)
  (add-hook 'prog-mode-hook #'eglot-ensure)
  (add-hook 'eglot-managed-mode-hook #'eldoc-box-hover-mode t)
          (use-package eglot-java
            :defer t
            :after eglot)
  
        (add-hook 'java-mode-hook 'eglot-java-mode)
            (with-eval-after-load 'eglot-java
                  (define-key eglot-java-mode-map (kbd "C-c l n") #'eglot-java-file-new)
                  (define-key eglot-java-mode-map (kbd "C-c l x") #'eglot-java-run-main)
                  (define-key eglot-java-mode-map (kbd "C-c l t") #'eglot-java-run-test)
                  (define-key eglot-java-mode-map (kbd "C-c l N") #'eglot-java-project-new)
                  (define-key eglot-java-mode-map (kbd "C-c l T") #'eglot-java-project-build-task)
                  (define-key eglot-java-mode-map (kbd "C-c l R") #'eglot-java-project-build-refresh))
;; eglot-setup ends here
(provide 'eglot-setup)
