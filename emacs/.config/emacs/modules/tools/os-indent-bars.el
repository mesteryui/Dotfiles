;;; -*- lexical-binding: t -*-

(use-package indent-bars
  :ensure t
  :hook (prog-mode . indent-bars-mode)
  :config
  (setq indent-bars-starting-column 0
        indent-bars-spacing 2)
  (setq indent-bars-prefer-character t) ;; Usa caracteres en lugar de imágenes de bits
  (setq indent-bars-no-descend-lists t) ;; No dibujes barras dentro de funciones/listas largas
  (setq indent-bars-display-on-blank-lines nil))

(provide 'os-indent-bars)
