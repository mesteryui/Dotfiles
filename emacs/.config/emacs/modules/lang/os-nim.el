;;; os-nim.el --- Nim configuration -*- lexical-binding: t; -*-

(use-package nim-mode            ; Modo mayor para NIM
  :defer t)
(use-package flycheck-nim        ; Comprobación del código al vuelo
  :defer t)
(use-package flycheck-nimsuggest ; Comprobación de código utilizando nimsuggest
  :defer t)
(use-package ob-nim              ; Paquete para ~org-babel~
  :defer t)
(add-hook 'nim-mode-hook 'nimsuggest-mode)

(provide 'os-nim)
