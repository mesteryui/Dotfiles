;; -*- lexical-binding: t; -*-
;; (use-package mixed-pitch
;;   :ensure t
;;   :hook (text-mode . mixed-pitch-mode)
;;   :config
;;   (add-to-list 'mixed-pitch-fixed-pitch-faces 'org-table))

(setq custom-safe-themes t)

(use-package ef-themes
  :ensure (:host github :repo "protesilaos/ef-themes")
  :demand t
  :init
  (add-hook 'text-mode-hook #'variable-pitch-mode)
  :config
  (ef-themes-take-over-modus-themes-mode 1)
  (setopt modus-themes-variable-pitch-ui t
	  modus-themes-mixed-fonts t
	  modus-themes-headings '((agenda-date . (1.3))
				  (agenda-structure . (variable-pitch light 1.8))
				  (0 . (variable-pitch light 1.7))
				  (1 . (variable-pitch 1.5))
				  (2 . (variable-pitch 1.4))
				  (3 . (variable-pitch 1.25))
				  (4 . (variable-pitch 1.1))
				  (t . (variable-pitch 1.0))))
  (setq modus-themes-italic-constructs t)
  (modus-themes-load-theme 'ef-cherie))

;;(add-to-list 'initial-frame-alist '(fullscreen . maximized)) ;; Empezar maximizado
(global-display-line-numbers-mode -1)
(add-to-list 'default-frame-alist '(undecorated . t))
(tool-bar-mode -1)                                            ; Desactivar la barra de herramientas
(menu-bar-mode -1)                                            ; Desactivar la barra de menús
(scroll-bar-mode -1)                                          ; Desactivar la barra de desplazamiento visible
(tooltip-mode -1)
(pixel-scroll-precision-mode t)
(blink-cursor-mode -1)                                ; Steady cursor
(setq pixel-scroll-precision-interpolate-page t)
;;(set-fringe-mode 10)        ; Give some breathing room
(setq-default cursor-type 'bar) ;; Barra de cursor
(delete-selection-mode t)
(setq server-client-instructions nil) ;; Evita que me salgan avisos de como se cierra el cliente
(setopt use-dialog-box nil)

(set-face-attribute 'default nil
		    :font "JetBrainsMono Nerd Font"
		    :height 110
		    :weight 'medium)
(set-face-attribute 'variable-pitch nil
		    :font "Aporetic Sans"
		    :height 110
		    :weight 'medium)
(set-face-attribute 'fixed-pitch nil
		    :font "JetBrainsMono Nerd Font"
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

(add-to-list 'default-frame-alist '(font . "JetBrainsMono Nerd Font-11"))


;; Uncomment the following line if line spacing needs adjusting.
;;(setq-default line-spacing 0.3)

(add-to-list 'default-frame-alist '(alpha-background . 92)) ; For all new frames henceforth

(use-package spacious-padding
  :ensure t
  ;;:hook (elpaca-after-init . spacious-padding-mode)
  :bind ("<f6>" . spacious-padding-mode)
  :config 
  (setq spacious-padding-widths
	'(:internal-border-width 6
				 :header-line-width 4
				 :mode-line-width 5
				 :tab-width 4
				 :right-divider-width 30
				 :fringe-width 8)))

(provide 'ui)
