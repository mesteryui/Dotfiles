;;; os-vertico.el --- Vertico configuration -*- lexical-binding: t; -*-

;;; Code:

(use-package vertico
  :ensure t
  :hook (elpaca-after-init . vertico-mode)
  :custom
  (vertico-count 12)
  (vertico-resize t)
  (vertico-cycle t)
  :config
  ;; Habilitamos multiform para permitir diferentes vistas (como el grid)
  (vertico-multiform-mode 1)
  
  ;; CONFIGURACIÓN CLAVE:
  ;; Para embark-keybinding, usamos 'posframe' Y 'grid' a la vez.
  ;; Esto hace que la rejilla aparezca en la ventana flotante.
  (setq vertico-multiform-categories
        '((embark-keybinding posframe grid)
          (imenu posframe buffer)
          (file posframe))))

(use-package vertico-posframe
  :ensure t
  :after vertico
  :custom
  (vertico-posframe-parameters
   '((left-fringe . 8)
     (right-fringe . 8)
     (internal-border-width . 2)))
  :config
  ;; Handler para centrar la ventana
  (setq vertico-posframe-poshandler #'posframe-poshandler-frame-center)
  
  ;; No activamos vertico-posframe-mode globalmente para dejar que 
  ;; vertico-multiform decida cuándo usarlo (según lo configurado arriba).
  ;; Esto evita conflictos y hace el comportamiento más predecible.
  (vertico-posframe-mode 1))

(use-package emacs
  :ensure nil
  :custom
  (enable-recursive-minibuffers t)
  (read-extended-command-predicate #'command-completion-default-include-p)
  (minibuffer-prompt-properties
   '(read-only t cursor-intangible t face minibuffer-prompt)))

(provide 'os-vertico)
