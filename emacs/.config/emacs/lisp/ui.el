(use-package mixed-pitch
  :ensure t
  :hook (text-mode . mixed-pitch-mode)
  :config
  (add-to-list 'mixed-pitch-fixed-pitch-faces 'org-table))

(defun os/org-headers-setters ()
  "Ajusta de forma personalizada los encabezados del modo org"
  (dolist (item '((org-level-1 . outline-1)
		  (org-level-2 . outline-2)
		  (org-level-3 . outline-3)
		  (org-level-4 . outline-4)))
    (set-face-attribute (car item) nil :inherit (cdr item)))
  (dolist (item '((org-level-1 . 1.5)
		  (org-level-2 . 1.4)
		  (org-level-3 . 1.25)
		  (org-level-4 . 1.1)
		  (org-document-title . 1.7)))
    (set-face-attribute (car item) nil :height (cdr item))))

(setq custom-safe-themes t)

(use-package ef-themes
  :ensure t
  :custom (ef-themes-mixed-fonts t)
  :config
  (seq-do #'disable-theme custom-enabled-themes)
  (ef-themes-select 'ef-trio-dark))

(add-to-list 'initial-frame-alist '(fullscreen . maximized)) ;; Empezar maximizado
(add-to-list 'default-frame-alist '(undecorated . t))
(tool-bar-mode -1)                                            ; Desactivar la barra de herramientas
(menu-bar-mode -1)                                            ; Desactivar la barra de menús
(scroll-bar-mode -1)                                          ; Desactivar la barra de desplazamiento visible
(tooltip-mode -1)
(pixel-scroll-precision-mode t)
(blink-cursor-mode -1)                                ; Steady cursor
(setq pixel-scroll-precision-interpolate-page t)
(set-fringe-mode 10)        ; Give some breathing room
(setq-default cursor-type 'bar) ;; Barra de cursor
(delete-selection-mode t)
(setq server-client-instructions nil) ;; Evita que me salgan avisos de como se cierra el cliente
(setopt use-dialog-box nil)

(set-face-attribute 'default nil
:font "Aporetic Sans Mono"
:height 110
:weight 'medium)
(set-face-attribute 'variable-pitch nil
:font "Aporetic Sans"
:height 110
:weight 'medium)
(set-face-attribute 'fixed-pitch nil
:font "Aporetic Sans Mono"
:height 1.0
:weight 'medium)
;; Makes commented text and keywords italics.
;; This is working in emacsclient but not emacs.
;; Your font must have an italic face available.
(set-face-attribute 'font-lock-comment-face nil
:slant 'italic)
(set-face-attribute 'font-lock-keyword-face nil
:slant 'italic)


;; This sets the default font on all graphical frames created after restarting Emacs.
;; Does the same thing as 'set-face-attribute default' above, but emacsclient fonts
;; are not right unless I also add this method of setting the default font.

(add-to-list 'default-frame-alist '(font . "Aporetic Sans Mono-11"))


;; Uncomment the following line if line spacing needs adjusting.
(setq-default line-spacing 0.3)

;;(add-hook 'text-mode-hook #'variable-pitch-mode)

(add-to-list 'default-frame-alist '(alpha-background . 92)) ; For all new frames henceforth

(electric-pair-mode t)

(provide 'ui)
