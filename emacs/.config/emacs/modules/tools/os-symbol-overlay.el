;;; -*- lexical-binding: t -*-

(use-package symbol-overlay
  :ensure t
  :hook (prog-mode . symbol-overlay-mode) ;; Se activa en todos los lenguajes
  :config
  ;; Evita que el resaltado desaparezca al mover el cursor inmediatamente
  (setq symbol-overlay-idle-time 0.1))

(provide 'os-symbol-overlay)
