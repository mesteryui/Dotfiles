;;; os-corfu.el --- Corfu and Cape configuration -*- lexical-binding: t; -*-

;;; Code:

(require 'os-macros)

(use-package corfu
  :ensure t
  :hook (elpaca-after-init . global-corfu-mode)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.6)      ; Más tiempo antes de que aparezca el menú (antes 0.35)
  (corfu-auto-prefix 2)     ; Escribir 3 caracteres en lugar de 2 para disparar autocompletado
  (corfu-popupinfo-delay '(0.6 . 0.3))
  (corfu-cycle t)
  (corfu-count 16)
  (corfu-max-width 120)
  (corfu-quit-no-match t)
  (corfu-preselect 'prompt)
  (corfu-on-exact-match nil)
  (tab-always-indent 'complete)
  :config
  (corfu-history-mode 1)
  (corfu-popupinfo-mode 1)
  ;; Guardar el historial de completado
  (os/after savehist
	    (add-to-list 'savehist-additional-variables 'corfu-history)))



(use-package cape
  :ensure t
  :init
  ;; Estas son las fuentes "base" que siempre estarán disponibles
  ;; pero las pondremos al final de la lista para que no estorben al LSP.
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-elisp-block))

(provide 'os-corfu)
