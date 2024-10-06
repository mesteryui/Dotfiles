;;; Package --- init.el
;;; Commentary:
;; Aqui empieza el archivo init.el lo primero que hace este archivo es cargar el archivo config.org y crear un archivo config.el para usar la configuracion desde ahi
;;; Code:
(org-babel-load-file
 (expand-file-name
  "config.org"
  user-emacs-directory))
(provide 'init)
;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(eglot)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
