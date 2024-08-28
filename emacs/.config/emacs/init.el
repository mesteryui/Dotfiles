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
