;; -*- lexical-binding: t; -*-

(use-package org-social
  :ensure (:host github :repo "tanrax/org-social.el")
  :config
  (setq org-social-file "~/Escritorio/CosasSociales/social.org")
  (setq org-social-my-public-url "https://codeberg.org/mester/CosasSociales/raw/branch/main/social.org"))



(use-package os-scratch
  :load-path "os-lisp/"
  :config
  (add-to-list 'os-scratch-messages `(text . ,(format "Welcome to text-mode %s." user-full-name))))

(use-package organizer
  :after org
  :load-path "os-lisp/Organizer/"
  :config
  (gbind "<f12>" organizer-index)
  (add-to-list 'organizer-files `("Libros" . ,(expand-file-name "Libros.org" org-directory)))
  (add-to-list 'organizer-files `("Finanzas" . ,(expand-file-name "Finanzas.org" org-directory))))

;;; Pass interface (password-store)
(use-package password-store
  :ensure t
  ;; Mnemonic is the root of the "code" word (κώδικας).  But also to add
  ;; the password to the kill-ring.  Other options are already taken.
  :bind ("C-c k" . password-store-copy)
  :config
  (setq password-store-time-before-clipboard-restore 30))

(use-package pass
  :ensure t
  :commands (pass))

;; Helpful is an alternative to the built-in Emacs help that provides much more
;; contextual information.
(use-package helpful
  :ensure t
  :commands (helpful-callable
             helpful-variable
             helpful-key
             helpful-command
             helpful-at-point
             helpful-function)
  :bind
  ([remap describe-command] . helpful-command)
  ([remap describe-function] . helpful-callable)
  ([remap describe-key] . helpful-key)
  ([remap describe-symbol] . helpful-symbol)
  ([remap describe-variable] . helpful-variable)
  :custom
  (helpful-max-buffers 7))


(use-package ace-window
  :ensure t
  :defer t
  :init
  (global-set-key [remap other-window] 'ace-window)
  (custom-set-faces
   '(aw-leading-char-face
     ((t (:inherit ace-jump-face-foreground :height 3.0)))))
  ;; :custom
  ;; (aw-dispatch-always t)                ;; Don't if you want change windows with only two windows
  )


(use-package calfw
  :config
  (setopt cfw:org-overwrite-default-keybinding t)) ;; atajos de teclado de la agenda org-mode
(setopt cfw:display-calendar-holidays t) ;; para esconder fiestas calendario emacs
(use-package calfw-org
  :after calfw
  :ensure t
  :config
  (setq cfw:org-overwrite-default-keybinding t)
  :bind ([f8] . calfw-org-open-calendar))


(use-package autorevert
  :ensure nil
  :diminish
  :hook (after-init . global-auto-revert-mode))

(moon-loader-add-modules eshell-tools)

(setopt dictionary-use-single-buffer t)
(setopt dictionary-server "dict.org")

(use-package treemacs
  :defer t
  :init
  (global-set-key (kbd "C-c d") 'treemacs)
  (setq treemacs-hide-gitignored-files-mode t
	treemacs-project-follow-cleanup t
	treemacs-width 45
	treemacs-width-is-initially-locked nil
	delete-by-moving-to-trash t
	treemacs-collapse-dirs 3
	treemacs-display-in-side-window t
	treemacs-is-never-other-window t
	treemacs-indentation 2
	treemacs-indentation-string " "
	treemacs-filewatch-mode t
	treemacs-git-mode 'deferred
	treemacs-text-scale 1
	treemacs-move-files-by-mouse-dragging nil
	treemacs-move-forward-on-expand t
	treemacs-pulse-on-success t
	treemacs-file-event-delay 0
	treemacs-deferred-git-apply-delay 0
	treemacs-git-commit-diff-mode 1)
  (add-hook 'treemacs-mode-hook #'treemacs-project-follow-mode))
(use-package treemacs-nerd-icons
  :after nerd-icons
  :config
  (treemacs-load-theme "nerd-icons"))
(global-set-key (kbd "C-c f") 'treemacs)

(use-package ledger-mode
  :ensure t)

;; use-package with package.el:

(use-package which-key
  :ensure nil
  :after (embark vertico)
  :config
  (which-key-mode)
  (setq prefix-help-command #'embark-prefix-help-command)
  :custom
  (which-key-idle-delay 0.2)
  (which-key-separator " → ") 
  (which-key-ellipsis "…"))

(use-package eradio
  :commands (eradio-play eradio-toggle)
  :custom
  (eradio-player '("mpv" "--no-video" "--no-terminal"))
  (eradio-channels '(("MGT Radio" . "https://stream.zeno.fm/koq3futfevouv") ;Esto con el punto se usa para crear un par asi podemos extraer uno u otro
		     ("Radio asiatica" . "https://stream.zeno.fm/vwvzwtapjrpvv")
		     ("Radio Libretics" . "https://stream-170.zeno.fm/a79lrhms108uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJhNzlscmhtczEwOHV2IiwiaG9zdCI6InN0cmVhbS0xNzAuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IndQLS1ld3VYVGV5RjcxNUtmaXdMRkEiLCJpYXQiOjE3NDIxNTQ3NzIsImV4cCI6MTc0MjE1NDgzMn0.nR6YeM5BOcjVXbKfFaSLO6v_kLFFvdgnbGRtaO_UblY")
		     ("Cadena Dial" . "http://playerservices.streamtheworld.com/api/livestream-redirect/CADENADIAL.mp3")
		     ("Los 40 Principales" . "https://23553.live.streamtheworld.com:443/LOS40.mp3"))))
(gbind-multiple ("C-x r e" . eradio-toggle)
		("C-x r p" . eradio-play))

(use-package doc-view
  :demand t
  :ensure nil
  :custom
  (doc-view-resolution 300)
  (doc-view-mupdf-use-svg t)
  (large-file-warning-threshold (* 50 (expt 2 20)))
  :config
  (add-hook 'doc-view-mode-hook 'pdf-tools-install)
  (setq-default pdf-view-use-scaling t
		pdf-view-use-imagemagick nil))
;; (use-package reader
;;   :ensure '(reader :type git :host codeberg :repo "divyaranjan/emacs-reader"
;; 	      :files ("*.el" "render-core.so")
;; 	      :pre-build ("make" "all")))
(use-package nov
  :ensure t
  :mode ("\\.epub\\'" . nov-mode))


;;; TMR May Ring (tmr is used to set timers)
;; Read the manual: <https://protesilaos.com/emacs/tmr>.
(use-package tmr
  :ensure t
  :bind
  ("C-c t" . tmr-prefix-map)
  :config
  (setq tmr-sound-file "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
	tmr-notification-urgency 'normal
	tmr-description-list 'tmr-description-history))

(defun set-markdown-headers () 
  "Setting the headers to a markdown file"
  (set-face-attribute 'markdown-header-face-1 nil :height 2.0)
  (set-face-attribute 'markdown-header-face-2 nil :height 1.75)
  (set-face-attribute 'markdown-header-face-3 nil :height 1.5)
  (set-face-attribute 'markdown-header-face-4 nil :height 1.3)
  (set-face-attribute 'markdown-header-face-5 nil :height 1.15)
  (set-face-attribute 'markdown-header-face-6 nil :height 1.05))
;; :hook ((markdown-mode . set-markdown-headers)
;;         (gfm-mode . set-markdown-headers))



(use-package typst-mode
  :ensure (:type git :host github :repo "Ziqi-Yang/typst-mode.el")
  :custom 
  (typst-ts-mode-watch-options "--open")
  (typst-ts-mode-enable-raw-blocks-highlight t)
  (typst-ts-mode-highlight-raw-blocks-at-startup t))


(use-package fish-mode
  :ensure t)

(use-package yuck-mode :ensure t)

(use-package i3wm-config-mode
  :ensure t
  :mode
  ("/sway/.*config.*/" . i3wm-config-mode)
  ("/sway/config\\'" . i3wm-config-mode))

(use-package savehist
  :ensure nil
  :hook (after-init . savehist-mode))

(use-package jsonrpc
  :ensure t)
(provide 'packages)
