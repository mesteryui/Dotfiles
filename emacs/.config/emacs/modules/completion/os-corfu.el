;;; os-corfu.el --- Corfu and Cape configuration -*- lexical-binding: t; -*-

;;; Code:

(require 'os-macros)

(use-package corfu
  :ensure t
  :hook (elpaca-after-init . global-corfu-mode)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.25)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-separator ?\s)
  (corfu-quit-no-match t)
  (corfu-preview-current 'prompt)
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
