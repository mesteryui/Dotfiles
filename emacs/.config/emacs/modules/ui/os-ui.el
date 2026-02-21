;;; -*- lexical-binding: t -*-
(setq custom-safe-themes t)
(setq-default 
 ;; Evita que Emacs intente redibujar todo el frame si solo cambió una línea
 redisplay-skip-fontification-on-input t
 ;; No pauses el dibujado si hay entrada pendiente (evita el efecto "ghosting")
 redisplay-dont-pause t
 ;; Acelera el procesado de timers para que no se amontonen (el 17% que tenías)
 idle-update-delay 0.1)

;;(add-to-list 'custom-theme-load-path "~/.config/emacs/themes/")
;;(load-theme 'noctalia t)


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
(setq-default cursor-in-non-selected-windows nil)
(delete-selection-mode t)
(setq server-client-instructions nil) ;; Evita que me salgan avisos de como se cierra el cliente
(setopt use-dialog-box nil)

(defun set-fonts ()
  "Set the fonts in a correct way"
  (set-face-attribute 'default nil
		      :font "Geist Mono Nerd Font"
		      :height 116
		      :weight 'medium)
  (set-face-attribute 'variable-pitch nil
		      :font "Google Sans Flex"
		      :height 120
		      :weight 'medium)
  (set-face-attribute 'fixed-pitch nil
		      :font "Geist Mono Nerd Font"
		      :height 1.0
		      :weight 'medium)

  ;; Makes commented text and keywords italics.
  ;; This is working in emacsclient but not emacs.
  ;; Your font must have an italic face available.
  (set-face-attribute 'font-lock-comment-face nil
		      :slant 'italic)
  (set-face-attribute 'font-lock-keyword-face nil
		      :slant 'italic)
  (message "Fonts setted"))


;; This sets the default font on all graphical frames created after restarting Emacs.
;; Does the same thing as 'set-face-attribute default' above, but emacsclient fonts
;; are not right unless I also add this method of setting the default font.
(if (daemonp)
    (add-hook 'after-make-frame-functions (lambda (frame)
					    (with-selected-frame frame
					      (set-fonts))))
  (set-fonts))

;; Uncomment the following line if line spacing needs adjusting.
;;(setq-default line-spacing 0.3)

;;(add-to-list 'default-frame-alist '(alpha-background . 90)) ; For all new frames henceforth

(use-package spacious-padding
  :ensure t
  :hook (elpaca-after-init . spacious-padding-mode)
  :bind ("<f6>" . spacious-padding-mode)
  :config
  (setq spacious-padding-widths
	'(:internal-border-width 15
				 :header-line-width 4
				 :mode-line-width 4
				 :custom-button-width 2
				 :tab-width 4
				 :right-divider-width 12
				 :scroll-bar-width 8
				 :fringe-width 13
				 ))
  )

(provide 'os-ui)
