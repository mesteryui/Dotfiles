;; Package -- Eglot setup
;; Comment:
;;
(use-package eglot
    :defer t
    :after elpaca)
  ;(add-hook 'compilation-mode-hook #'comint-mode)
  (add-hook 'prog-mode-hook #'eglot-ensure)
  (add-hook 'eglot-managed-mode-hook #'eldoc-box-hover-mode t)


;; eglot-setup ends here
(provide 'eglot-setup)
