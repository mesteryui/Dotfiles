;; -*- lexical-binding: t; -*- 
(use-package iedit
  :ensure t
  :config
  (gbind "C-v" iedit-mode))
(use-package vundo
  :bind ("C-x u" . vundo)
  :config (setq vundo-compact-display t))
(use-package super-save
  :config
  (setopt super-save-triggers
	  '(other-window  ; Al cambiar de ventana
	    switch-to-buffer  ; Al cambiar de buffer
	    mouse-leave-buffer-hook)) ; Al mover el ratón fuera de Emacs
  (setq super-save-idle-duration 1)  ; 0.3 segundos de inactividad
  (setopt super-save-auto-save-when-idle t)
  (super-save-mode 1)) ; Opcional: guardar también en inactividad
(provide 'editing)
