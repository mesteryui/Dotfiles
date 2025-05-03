;; -*- lexical-binding: t; -*-

;;(add-to-list 'load-path "~/.config/emacs/scripts/")

(dolist (item '((org-level-1 . (1.5 . outilne-1))
		  (org-level-2 . (1.4 . outline-2))
	          (org-level-3 . (1.25 . outline-3))
                  (org-level-3 . (1.1 . outline-3))
                  (org-document-title . (1.7 . default))))
  (set-face-attribute (car item) nil :inherit (cddr item) :height (cadr item)))


    (set-face-attribute 'org-block nil :foreground nil :inherit 'fixed-pitch)
    (set-face-attribute 'org-table nil  :inherit 'fixed-pitch)
    (set-face-attribute 'org-formula nil :inherit 'fixed-pitch)
    (set-face-attribute 'org-code nil  :inherit '(shadow fixed-pitch))
    (set-face-attribute 'org-table nil :inherit '(shadow fixed-pitch))
    (set-face-attribute 'org-verbatim nil :inherit '(shadow fixed-pitch))
    (set-face-attribute 'org-special-keyword nil :inherit '(font-lock-comment-face fixed-pitch))
    (set-face-attribute 'org-meta-line nil :inherit '(font-lock-comment-face fixed-pitch))
    (set-face-attribute 'org-checkbox nil  :inherit 'fixed-pitch)
    (set-face-attribute 'line-number nil :inherit 'fixed-pitch)
    (set-face-attribute 'line-number-current-line nil :inherit 'fixed-pitch)

(setq custom-safe-themes t)

(use-package catppuccin-theme
  :config 
  (load-theme 'catppuccin t))

(tool-bar-mode -1)                                            ; Desactivar la barra de herramientas
(menu-bar-mode -1)                                            ; Desactivar la barra de menús
(scroll-bar-mode -1)                                          ; Desactivar la barra de desplazamiento visible
(tooltip-mode -1)

(set-fringe-mode 10)        ; Give some breathing room
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(setq void-text-area-pointer 'text)
(setq-default cursor-type 'bar) ;; Barra de cursor
(delete-selection-mode t)
(setq server-client-instructions nil) ;; Evita que me salgan avisos de como se cierra el cliente
(setopt use-dialog-box nil)
(display-time-mode 1)

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
;;(add-to-list 'default-frame-alist '(font . "JetBrains Mono NerdFont-10"))

;; Uncomment the following line if line spacing needs adjusting.
(setq-default line-spacing 0.3)

(add-hook 'text-mode-hook #'variable-pitch-mode)

(defun my/mhtml-use-fixed-pitch ()
  "Usar fuente monoespaciada en mhtml-mode."
  (setq buffer-face-mode-face 'fixed-pitch)
  (buffer-face-mode 1))
(add-hook 'mhtml-mode-hook #'my/mhtml-use-fixed-pitch)

(add-to-list 'default-frame-alist '(alpha-background . 92)) ; For all new frames henceforth

(electric-pair-mode t)

(setopt erc-nick "mester")
(setq erc-prompt-for-password (string-trim (shell-command-to-string "cat ~/Descargas/Conjuntos\ contraseña/password_irc")))
(setq erc-track-enable-keybindings t)
(setopt erc-fill-column 120
      erc-fill-function 'erc-fill-static
      erc-fill-static-center 20)

(setopt user-full-name "Oscar")
(setopt inhibit-startup-message t
        use-short-answers t
	blink-matching-parent t)

(global-set-key (kbd "C-+") 'text-scale-increase)
(global-set-key (kbd "C--") 'text-scale-decrease)

(setopt
 display-time-24hr-format t             ; Muestra el reloj en formato 24 hrs
 display-time-format "%H:%M"             ; Le da formato a la hora
 auto-save-default nil                   ; Deshabilita #file#
 load-prefer-newer t                     ; Prefiere la versión más reciente de un archivo.
 select-enable-clipboard t               ; Sistema de fusión y portapapeles de Emacs.
 vc-follow-symlinks t                    ; Siempre sigue los enlaces simbólicos.
 make-backup-files nil                   ; No realiza backups de ficheros
;; org-footnote-section "Referencias:"  ; cambio footnotes por referencias
 ;; global-hl-line-mode t                ; Highlight current line
 kill-ring-max 128                       ; Longitud máxima del anillo de matar
 create-lockfiles nil                    ; Impido la creación de ficheros .#
 )

(global-set-key [escape] 'keyboard-escape-quit)

(setopt calendar-month-name-array
      ["Enero" "Febrero" "Marzo" "Abril" "Mayo" "Junio"
       "Julio" "Agosto" "Septiembre" "Octubre" "Noviembre" "Diciembre"])

(setopt calendar-day-name-array
      ["Domingo" "Lunes" "Martes" "Miércoles" "Jueves" "Viernes" "Sábado"])

(setopt org-icalendar-timezone "Europe/Madrid") ;; timezone
(setopt calendar-week-start-day 1) ;; la semana empieza el lunes
;;(setq european-calendar-style t) ;; estilo europeo
(setopt calendar-date-style 'iso)
(setopt calendar-holidays '((holiday-fixed 1 1 "Año nuevo")
			  (holiday-fixed 5 17 "Dia de las letras gallegas")
			  (holiday-fixed 10 12 "Día de la Hispanidad")
			  (holiday-fixed 11 01 "Todos los Santos")
			  (holiday-fixed 12 06 "Constitución")
			  (holiday-fixed 3 28 "Reconquista de Vigo")
			  (holiday-fixed 5 1 "Dia del Trabajo")
			  (holiday-fixed 12 24 "Nochebuena")
			  (holiday-fixed 12 25 "Navidad")))

(defun os/reload-config ()
  "Recargar configuracion Emacs"
  (interactive)
  (load-file (expand-file-name "init.el" user-emacs-directory))
  (ignore (elpaca-process-queues)))
(global-set-key (kbd "C-c r") 'os/reload-config)

(defun os/open-config ()
  "Abrir configuracion de emacs"
  (interactive)
  (find-file (expand-file-name "config.org" user-emacs-directory)))
(global-set-key (kbd "C-x c") 'os/open-config)

(defun dictionary-switcher()
  "Cambiar entre los diccionarios de Español, Esperanto e Ingles mediante un menu interactivo solo entre esos y solo a un diccionario distinto al seteado."
  (interactive)
  (let* ((dic ispell-current-dictionary)
         (change
	  (completing-read "Seleccione el diccionario a usar: " '("eo" "es_ES" "en_US") nil t)))
    (unless (string= dic change)
      (ispell-change-dictionary change)
      (message "Diccionario cambiado desde %s a %s" dic change))))

(defun toggle-webserver ()
"Function to toggle a not much bigger webserver ChatGPT helping me to fix some things
This function allow to activate the webserver when you use but if there is a process of webserver the function kill it"
   (interactive)
   (let ((proc (get-process "webserver")))
         (if (and proc (eq (process-status proc) 'run))  ;; Verifica si el proceso está corriendo
             (progn
                (delete-process "webserver")
                (message "Webserver stopped"))
                (make-process :name "webserver" :command '("npx" "browser-sync" "start" "--server" "--files" "**/*") :buffer "*webserver*" :filter (lambda (_proc output)
                 (when (string-match "Local: http://localhost:3000" output) ;; Verificamos a traves de la salida si el servidor ya se ha desplegado
                   (message " ✅ Webserver started")))))))

(defun org-temp-buffer ()
   "Acceder a un buffer temporal de orgmode"
   (interactive)
   (if (get-buffer "*orgtemp*")
         (switch-to-buffer "*orgtemp*")
         (switch-to-buffer (get-buffer-create "*orgtemp*"))
         (insert (format "#+title: Org Temporal Buffer\n#+description: Espacio para la toma de notas temporales\n#+author: %s\n\n" user-full-name))
         (org-mode)))

(setopt org-directory "~/org/")
(setopt diary-file (expand-file-name "diario.org" org-directory))
(setopt org-default-notes-file (expand-file-name "notes.org" org-directory))
(setopt org-agenda-files `( ,(expand-file-name "agenda.org" org-directory) ,(expand-file-name "proyectos.org" org-directory)))
(setopt org-archive-location "~/org/%s_archivo.org::datetree/")

(setopt org-export-with-drawers nil
      org-export-with-todo-keywords nil
      org-export-with-broken-links t
      org-export-with-toc nil
      org-export-with-smart-quotes t
      org-export-date-timestamp-format "%d %B %Y"
      org-list-allow-alphabetical t)

 (setopt org-return-follows-link  t) ;; Hace que pulsando Enter funcione el seguir el enlace
 (require 'org-tempo)               
(use-package org
    :ensure nil)
(setq org-ellipsis "▼")
(setq-default org-startup-indented t
                    org-pretty-entities t
                    org-use-sub-superscripts "{}"
                    org-hide-emphasis-markers t
                    org-startup-with-inline-images t
                    image-actual-width '(300))
(add-hook 'org-mode-hook 'org-indent-mode)
        (global-set-key (kbd "C-c c") 'org-capture)
        (global-set-key (kbd "C-c a") 'org-agenda)

(setopt org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "WAITING(w)" "PAUSED(P)" "|" "DONE(d)" "CANCELLED(c)")))
    (setopt org-todo-keyword-faces
           '(("TODO" . "coral")
             ("NEXT" . "cyan")
 	        ("WAITING" . "yellow")
             ("DONE" . "green")
             ("PAUSED" . "IndianRed1")
             ("CANCELLED" . "grey")))

(electric-indent-mode 0)
(setq org-edit-src-content-indentation 0
      org-src-preserve-indentation nil)

(setq org-src-tab-acts-natively t
      org-src-fontify-natively t)

(use-package org-appear
       :hook
(org-mode . org-appear-mode))
  ;; ;; Modern Org mode interface
  (use-package org-modern
      :after org
      :hook   (org-mode . org-modern-mode)
              (org-agenda-finalize . org-modern-agenda)
      :custom
      (org-modern-block-indent t)  ; to enable org-modern-indent when org-indent is active
      (org-modern-keyword t)
      (org-modern-table nil)
      (org-modern-star 'replace)
      (org-modern-replace-stars "◉○◈◇✿✳")
      (org-modern-checkbox
       '((?X . "✔")
         (?- . "┅")
         (?\s . "")))
      (org-modern-list '((?+ . "➤") (?- . "✦") (?* . "•")))
      (org-modern-todo-faces
            '(("TODO" :background "coral" :foreground "black")
              ("NEXT" :background "cyan" :foreground "black")
              ("PAUSED" :background "IndianRed1" :foreground "black")
              ("WAITING" :background "yellow" :foreground "black")
              ("DONE" :background "green" :foreground "white")
              ("CANCELLED" :background "gray" :foreground "white")))
      (org-modern-label-border 1))
(use-package ox-epub
        :demand t)
(use-package ox-reveal)

(setq org-capture-templates
        `(("t" "Tarea" entry
           (file+headline "~/org/agenda.org" "Tareas")
           "* TODO %?\n  Creado: %U\n  %i\n  %a")
          ("n" "Nota" entry
           (file+headline "~/org/notes.org" "Notas")
           "* %? :nota:\n  Creado: %U\n  %i\n %a")
	  ("e" "Evento" entry
	   (file+headline "~/org/agenda.org" "Evento")
	   "* WAITING %?\n"
	   )
          ("j" "Diario" entry
           (file+datetree "~/org/diario.org")
           "* Titulo de Entrada: %?\n")
	   ("p" "Project" entry
           (file+headline "~/org/proyectos.org" "Proyectos")
           "*  %?\n")))

(org-babel-do-load-languages
 'org-babel-load-languages
 '((emacs-lisp . t)
   (scheme . t)
   (python . t)
   (shell . t)
   ))

(use-package org-auto-tangle
  :defer t
  :hook (org-mode . org-auto-tangle-mode))

(use-package toc-org
    :demand t
    :commands toc-org-enable
    :init (add-hook 'org-mode-hook 'toc-org-enable))

(use-package org-crypt
    :ensure nil
    :after org
    :config
    (setq org-tags-exclude-from-inheritance (quote ("crypt")))
    :custom
    (org-crypt-key "oscarodriguez56@gmail.com"))

(use-package org-contrib
 :after org
 :config
 (org-babel-do-load-languages
  'org-babel-load-languages
  '((ledger . t))))

(use-package tramp
  :ensure nil
  :custom
  (tramp-persistency-file-name
   (no-littering-expand-var-file-name "tramp/history.el")))

(use-package nerd-icons
    :ensure t)
  (use-package nerd-icons-completion
    :ensure t
    :after (marginalia nerd-icons)
    :hook (marginalia-mode . nerd-icons-completion-marginalia-setup)
    :init (nerd-icons-completion-mode))
(use-package nerd-icons-corfu
   :after (corfu nerd-icons)
   :config
   (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

(use-package calfw
  :config
  (setopt cfw:org-overwrite-default-keybinding t)) ;; atajos de teclado de la agenda org-mode
  (setopt cfw:display-calendar-holidays t) ;; para esconder fiestas calendario emacs

(use-package calfw-org
  :after calfw
  :ensure t
  :config
  (setq cfw:org-overwrite-default-keybinding t)
  :bind ([f8] . cfw:open-org-calendar))

(use-package vterm
  :defer t
  :bind
  (:map
   vterm-mode-map
   ("C-y" . vterm-yank)
   ("C-q" . vterm-send-next-key)))
(use-package vterm-toggle
  :bind (("C-c g" . vterm-toggle)))

;; ;; Aun no soportado en la shell de comandos que uso
(use-package eat
   :ensure t)

(use-package dired-sidebar
    :ensure t
    :defer t
    :commands (dired-sidebar-toggle-sidebar)
    :init
    (setopt dired-sidebar-theme 'nerd)
    (setopt dired-sidebar-use-term-integration t)
    (setopt dired-sidebar-use-custom-font t))
  (use-package dired-git
    :ensure t)
(global-set-key (kbd "C-c s") 'dired-sidebar-toggle-sidebar)

(use-package autorevert
:ensure nil
:diminish
:hook (after-init . global-auto-revert-mode))

(setq eshell-prompt-function
      (lambda ()
        (let ((status (if (= eshell-last-command-status 0)
                          (propertize "✔" 'face '(:foreground "green"))
                        (propertize "✘" 'face '(:foreground "red")))))
          (concat
	   (propertize " " 'face '(:foreground "cyan"))
           (propertize (user-login-name))
           "@"
           (propertize (system-name) 'face '(:foreground "green"))
           " "
           (propertize (abbreviate-file-name (eshell/pwd)) 'face '(:foreground "yellow"))
           " " status "\n"
           " "))))

(defun eshell/clear ()
  "Borrar completamente el historial de eshell usando `clear-scrollback`."
  (interactive)
  (eshell-clear-scrollback))

      (use-package eshell
        :ensure nil
	 :hook ((eshell-load . eat-eshell-mode)
		(eshell-load . eat-eshell-visual-command-mode))
	:config
	(setopt eshell-scroll-to-bottom-on-input 'this   ;; Desplazar abajo al escribir
	      eshell-buffer-maximum-lines 5000     ;; Limitar líneas en el buffer
          eshell-hist-ignoredups t             ;; Evitar duplicados en el historial
	  eshell-destroy-buffer-when-process-dies t) ;; Cerrar buffer si el proceso muere
	)
      (use-package eshell-toggle
      :ensure t
      :custom
    (eshell-toggle-size-fraction 3))
      (use-package eshell-syntax-highlighting
        :after esh-mode
        :config
        (eshell-syntax-highlighting-global-mode +1))
      (global-set-key (kbd "C-c t") 'eshell-toggle)

(use-package flyspell
      :ensure nil
      :defer t
      :init
      :config
      (setopt ispell-silently-savep t
        flyspell-case-fold-duplications t
        flyspell-issue-message-flag nil
        flyspell-default-dictionary "es_ES"
        ispell-program-name "hunspell"
        ispell-alternate-dictionary "/usr/share/dict/words") ;; Instalar paquete words en a
     :hook (text-mode . flyspell-mode)
     :bind(("M-<f7>" . flyspell-buffer)
           ("<f7>" . flyspell-word)))

(global-set-key (kbd "M-<f7>") 'dictionary-switcher)
  (use-package flyspell-correct
    :after (flyspell)
    :bind (("C-;" . flyspell-auto-correct-previous-word)
           ("<f7>" . flyspell-correct-wrapper)))

(use-package undo-tree
:init
(global-undo-tree-mode 1)
:custom
(undo-tree-visualizer-timestamps t)
(undo-tree-visualizer-diff t)
(undo-tree-auto-save-history nil))

(use-package treemacs
 :config 
(setopt treemacs-hide-gitignored-files-mode t)
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
  (add-hook 'treemacs-mode-hook #'treemacs-project-follow-mode)
(use-package treemacs-nerd-icons
  :after nerd-icons
  :config
  (treemacs-load-theme "nerd-icons"))
(global-set-key (kbd "C-c f") 'treemacs)

(use-package ledger-mode
  :ensure t)

(use-package embark
    :bind
    (("C-." . embark-act)
     ("C-:" . embark-dwim)
     ("C-h B" . embark-bindings)))

(use-package embark-consult
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;; use-package with package.el:
(use-package dashboard
  :ensure t
  :custom-face
  (dashboard-footer-face ((t (:inherit font-lock-doc-face :slant italic :height 0.98))))
  :custom
  (initial-buffer-choice 'dashboard-open)
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)
  (dashboard-icon-type 'nerd-icons)
  (dashboard-display-icons-p t)     ; display icons on both GUI and terminal
  (dashboard-vertically-center-content t)
  (dashboard-banner-logo-title (format "Bienvenido a Emacs %s, %s" emacs-version user-full-name))
  (dashboard-startup-banner "~/.config/emacs/images/kawaii-sm.png")
  (dashboard-items '((recents . 5)
                     (agenda . 5)
                     (bookmarks . 3)))
  (dashboard-item-names '(("Recent Files:" . "Archivos Recientes:")
                          ("Bookmarks:" . "Marcadores:")
                          ("Agenda for the coming week:" . "Agenda para la próxima semana:")))
  (dashboard-navigator-buttons
   `((
      (,(nerd-icons-mdicon "nf-md-cog" :height 1.1 :v-adjust 0.0)
       "Settings" "Open Config file"
       (lambda (&rest _) (os/open-config)))
      (,(nerd-icons-flicon "nf-linux-hyprland" :height 1.1 :v-adjust 0.0)
       "WM Settings" "Hyprland settings"
       (lambda (&rest _) (find-file "~/.config/hypr/hyprland.conf")))
      (,(nerd-icons-mdicon "nf-md-notebook" :height 1.1 :v-adjust 0.0)
       "Index" "Index of my Org"
       (lambda (&rest _) (organizer-index))))))
  (dashboard-startupify-list
   '(dashboard-insert-newline
     dashboard-insert-banner
     dashboard-insert-newline
     dashboard-insert-banner-title
     dashboard-insert-newline
     dashboard-insert-navigator
     dashboard-insert-items
     dashboard-insert-newline
     dashboard-insert-footer
      dashboard-insert-init-info))
  :config
  (dashboard-modify-heading-icons '((recents   . "nf-oct-file")
                                     (projects  . "nf-oct-rocket")
                                     (bookmarks . "nf-oct-bookmark")
                                     (agenda    . "nf-oct-calendar")
                                     (registers . "nf-oct-note")))
  (add-hook 'elpaca-after-init-hook #'dashboard-insert-startupify-lists)
  (add-hook 'elpaca-after-init-hook #'dashboard-initialize)
  (dashboard-setup-startup-hook))
(global-set-key (kbd "<f10>") 'open-dashboard)
  (defun open-dashboard ()
    "Abre el buffer *dashboard* y salta al primer widget."
    (interactive)
    (delete-other-windows)
    ;; Refresca  dashboard buffer
    (if (get-buffer dashboard-buffer-name)
        (kill-buffer dashboard-buffer-name))
    (dashboard-insert-startupify-lists)
    (switch-to-buffer dashboard-buffer-name))

(use-package doom-modeline
    :after (nerd-icons)
    :hook (elpaca-after-init-hook . doom-modeline-mode)
    :custom
    (doom-modeline-height 25)
    (doom-modeline-icon t))

(use-package vertico
  :init
  (vertico-mode)
  :custom
  (vertico-count 15)                    ; Número de candidatos a mostrar
  (vertico-resize t)
  (vertico-cycle t)
  (vertico-sort-function 'vertico-sort-history-alpha))

(use-package marginalia
   :after vertico
   :custom
  (marginalia-annotators
   '(marginalia-annotators-heavy marginalia-annotators-lv))
      :init
      (marginalia-mode))

(use-package orderless
  :defer t
:custom
(completion-styles '(orderless basic))
(completion-category-defaults nil)
(completion-category-overrides
 '((file (styles partial-completion)))))

(use-package consult
  :demand t
  :bind (
       ("C-c M-x" . consult-mode-command)
       ;; ("C-c k" . consult-kmacro)
       ("C-x b" . consult-buffer)                ;; orig. switch-to-buffer
       ("C-x r b" . consult-bookmark)            ;; orig. bookmark-jump
       ("M-y" . consult-yank-pop)                ;; orig. yank-pop
       ("M-g o" . consult-outline)               ;; Alternativa: consult-org-heading
       ("M-g i" . consult-imenu)
       ("M-g I" . consult-imenu-multi)
       ("M-s d" . consult-find)                  ;; Alternativa: consult-fd
       ("M-s g" . consult-grep)
       ("C-s" . consult-line)))

(use-package which-key
 :ensure nil
 :delight
 :config
 (which-key-mode)
 (setopt which-key-idle-delay 0.3
         which-key-dont-use-unicode nil
         which-key-separator " → " 
         which-key-ellipsis "…"))

(use-package organizer
  :ensure nil
  :load-path "Organizer/"
  :config
  (global-set-key (kbd "<f12>")  'organizer-index)
  (add-to-list 'organizer-files `("Libros" . ,(expand-file-name "Libros.org" org-directory)))
  (add-to-list 'organizer-files `("Finanzas" . ,(expand-file-name "Finanzas.org" org-directory))))

(defun ews-distraction-free ()
 "Distraction-free writing environment using Olivetti package."
 (interactive)
 (if (equal olivetti-mode nil)
     (progn
       (window-configuration-to-register 1)
       (delete-other-windows)
       (text-scale-set 2)
       (olivetti-mode t))
   (progn
     (if (eq (length (window-list)) 1)
         (jump-to-register 1))
     (olivetti-mode 0)
     (text-scale-set 0))))
(use-package olivetti
  :demand t
  :bind
  (("<f9>" . ews-distraction-free)))

(use-package eradio
  :defer t
  :init
  (setopt eradio-player '("mpv" "--no-video" "--no-terminal" "--force-seekable"))
  :config
  (setopt eradio-channels '(("MGT Radio" . "https://stream.zeno.fm/koq3futfevouv") ;Esto con el punto se usa para crear un par asi podemos extraer uno u otro
                        ("Radio asiatica" . "https://stream.zeno.fm/vwvzwtapjrpvv")
			("Radio Libretics" . "https://stream-170.zeno.fm/a79lrhms108uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJhNzlscmhtczEwOHV2IiwiaG9zdCI6InN0cmVhbS0xNzAuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IndQLS1ld3VYVGV5RjcxNUtmaXdMRkEiLCJpYXQiOjE3NDIxNTQ3NzIsImV4cCI6MTc0MjE1NDgzMn0.nR6YeM5BOcjVXbKfFaSLO6v_kLFFvdgnbGRtaO_UblY")
			("Cadena Dial" . "http://playerservices.streamtheworld.com/api/livestream-redirect/CADENADIAL.mp3"))))
(global-set-key (kbd "C-x r e") 'eradio-toggle)
(global-set-key (kbd "C-x r p") 'eradio-play)

(use-package elfeed
    :custom-face
    (elfeed-search-unread-title-face ((t (:inherit fixed-pitch))))
    :bind
    ("C-x w" . elfeed))

(use-package elfeed-protocol
    :ensure t
    :demand t
    :after elfeed
    :config
    (elfeed-protocol-enable)
    :custom
    (elfeed-use-curl t)
    (elfeed-set-timeout 36000)
    (elfeed-log-level 'debug)
    (elfeed-protocol-feeds (list
                   (list "fever+https://Mester@rss.hostux.net"
                         :api-url "https://Mester@rss.hostux.net/api/fever.php"
                         :password (string-trim (shell-command-to-string "pass show freshrss"))))))

(use-package elfeed-dashboard
  :ensure t
  :after (elfeed elfeed-protocol)
  :config
  (setopt elfeed-dashboard-file (expand-file-name "elfeed-dashboard" user-emacs-directory))
  ;; update feed counts on elfeed-quit
  (advice-add 'elfeed-search-quit-window :after #'elfeed-dashboard-update-links))

(use-package super-save
  :config
  (setq super-save-triggers
  '(other-window  ; Al cambiar de ventana
    switch-to-buffer  ; Al cambiar de buffer
    mouse-leave-buffer-hook)) ; Al mover el ratón fuera de Emacs
  (super-save-mode 1)
  (setopt super-save-idle-duration 1)  ; 0.3 segundos de inactividad
  (setopt super-save-auto-save-when-idle t)) ; Opcional: guardar también en inactividad

(use-package adaptive-wrap
  :config
  (adaptive-wrap-prefix-mode))

(use-package markdown-mode
  :demand t
  :commands (markdown-mode gfm-mode)
  :mode (("README\\.md\\'" . gfm-mode)
       ("\\.md\\'" . gfm-mode)
       ("\\.markdown\\'" . markdown-mode))
  :init (setq markdown-command "markdown2")
  :config
  (setq visual-line-column 80)
  (setopt markdown-fontify-code-blocks-natively t)
  (setopt markdown-enable-math t))
(use-package markdown-preview-eww
  :ensure t
  :after markdown-mode)

(use-package markdown-preview-mode
  :ensure t)

(use-package typst-mode
  :ensure (:type git :host github :repo "Ziqi-Yang/typst-mode.el")
  :custom 
  (typst-ts-mode-watch-options "--open")
  (typst-ts-mode-enable-raw-blocks-highlight t)
  (typst-ts-mode-highlight-raw-blocks-at-startup t))

(use-package hyprlang-ts-mode
  :ensure t
  :custom
  (hyprlang-ts-mode-indent-offset 4)
  :config 
  (add-to-list 'auto-mode-alist '("/hypr/.*config.*/" . hyprlang-ts-mode))
(add-to-list 'auto-mode-alist '("/hypr/config\\'" . hyprlang-ts-mode)))

(use-package fish-mode
  :ensure t
  :demand t)

(use-package i3wm-config-mode
  :demand t
  :ensure t
  :config
  (add-to-list 'auto-mode-alist '("/sway/.*config.*/" . i3wm-config-mode))
(add-to-list 'auto-mode-alist '("/sway/config\\'" . i3wm-config-mode)))

(use-package savehist
  :ensure nil
  :init
  (savehist-mode))

(use-package jsonrpc
  :ensure t)

(add-hook 'prog-mode-hook 'display-line-numbers-mode)
(setopt display-line-numbers-type 'relative)
(setq-default display-fill-column-indicator-column 79)
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)

(use-package eglot-tempel
  :preface (eglot-tempel-mode)
  :init
  (eglot-tempel-mode t))

(setopt flymake-fringe-indicator-position 'left-fringe)
(setopt flymake-show-diagnostics-at-end-of-line nil)

;; Suppress the display of Flymake error counters when there are no errors.
(setopt flymake-suppress-zero-counters t)

;; Disable wrapping around when navigating Flymake errors.
(setopt flymake-wrap-around nil)

(use-package transient)
(use-package magit
   :bind
   ("C-x g" . magit-status))

(use-package magit-stats
  :ensure t)

 (use-package git-gutter
   :defer 0.3
   :delight
   :init (global-git-gutter-mode))

 (use-package git-timemachine
   :defer 1
   :delight)

(use-package eldoc-box
  :ensure t
  :defer t)

;; Corfu: interfaz mínima y rápida de completado en buffer
(use-package corfu
  :ensure t
  :custom
  (corfu-separator ?\s)  ; separador de palabra
  (corfu-cycle t)                 ; Allows cycling through candidates
  (corfu-auto t)                  ; Enable auto completion
  (corfu-auto-prefix 2)
  (corfu-auto-delay 0.1)
  (corfu-popupinfo-delay '(0.5 . 0.2))
  (corfu-preview-current 'insert) ; insert previewed candidate
  (corfu-on-exact-match nil)
   :hook
    (elpaca-after-init . (lambda()
                           (global-corfu-mode)
                           (corfu-history-mode)
                           (corfu-popupinfo-mode))))      ; activación global
(use-package corfu-terminal
   :after corfu
   :ensure (:type git :repo "https://codeberg.org/akib/emacs-corfu-terminal.git")
   :config
   (unless (display-graphic-p)
      (corfu-terminal-mode)))
;; Cape: extensiones para completion-at-point
(use-package cape
  :ensure t
  :init
  (add-hook 'completion-at-point-functions #'cape-abbrev)
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-elisp-block)
  (add-hook 'completion-at-point-functions #'cape-emoji)
  (add-hook 'completion-at-point-functions #'cape-dict)
  (add-hook 'completion-at-point-functions #'cape-keyword))
;; Atajos prácticos
(global-set-key (kbd "M-<tab>") #'completion-at-point) ; TAB para completado

(use-package emacs
  :ensure nil
  :custom
  ;; TAB cycle if there are only few candidates
  ;; (completion-cycle-threshold 3)

  ;; Enable indentation+completion using the TAB key.
  ;; `completion-at-point' is often bound to M-TAB.
  (tab-always-indent 'complete)

  ;; Emacs 30 and newer: Disable Ispell completion function.
  ;; Try `cape-dict' as an alternative.
  (text-mode-ispell-word-completion nil)

  ;; Hide commands in M-x which do not apply to the current mode.  Corfu
  ;; commands are hidden, since they are not used via M-x. This setting is
  ;; useful beyond Corfu.
  (read-extended-command-predicate #'command-completion-default-include-p))

(use-package tempel
  :bind (("M-+" . tempel-complete) ;; o el keybinding que prefieras
         ("M-*" . tempel-insert))
  :custom
  (tempel-path "~/.config/emacs/templates.el") ;; o donde quieras tus plantillas
  :init
    (defun tempel-setup-capf ()
    ;; Add the Tempel Capf to `completion-at-point-functions'.
    ;; `tempel-expand' only triggers on exact matches. Alternatively use
    ;; `tempel-complete' if you want to see all matches, but then you
    ;; should also configure `tempel-trigger-prefix', such that Tempel
    ;; does not trigger too often when you don't expect it. NOTE: We add
    ;; `tempel-expand' *before* the main programming mode Capf, such
    ;; that it will be tried first.
    (setq-local completion-at-point-functions
                (cons #'tempel-expand (cons #'tempel-complete
                      completion-at-point-functions))))
  (add-hook 'conf-mode-hook 'tempel-setup-capf)
  (add-hook 'prog-mode-hook 'tempel-setup-capf)
  (add-hook 'text-mode-hook 'tempel-setup-capf)
  (add-hook 'org-mode-hook 'tempel-setup-capf)
  (add-hook 'eglot-managed-mode-hook 'tempel-setup-capf)
;; (add-hook 'eglot-java-mode-hook 'tempel-setup-capf)
 ;; (add-hook 'lsp-mode-hook 'tempel-setup-capf)
 ;; (add-hook 'lsp-mode 'tempel-setup-capf)
 ;; (add-hook 'lsp-after-initialize-hook 'tempel-setup-capf)
 ;; (add-hook 'lsp-on-idle-hook 'tempel-setup-capf)
  :config 
   (define-key tempel-map (kbd "TAB") #'tempel-next))

(use-package tempel-collection)

(use-package eglot
  :ensure nil
  :hook ((python-mode . eglot-ensure)
         (rust-mode . eglot-ensure)
         (js-mode . eglot-ensure)
         (html-mode . eglot-ensure)
         (mhtml-mode . eglot-ensure)
	 (java-mode . eglot-ensure)
	 (c-mode . eglot-ensure))
 :custom 
 (eglot-sync-connect 1)
 (eglot-autoshutdown t)
 (eglot-events-buffer-size 0)
 (eglot-auto-display-help-buffer nil)
   :bind
  (:map eglot-mode-map
        ;; Cada binding incluye el prefijo C-c l de forma literal
        ("C-c l r" . eglot-rename)
        ("C-c l a" . eglot-code-actions)
        ("C-c l f" . eglot-format-buffer)))
  (add-hook 'eglot-managed-mode-hook #'eldoc-mode)
  (add-hook 'eglot-managed-mode-hook #'eldoc-box-hover-mode t)

(use-package pyvenv
  :hook (pyvenv-mode . python-mode))

(defun uv-project-run (archivo)
  "Ejecuta el archivo que desees de un proyecto con uv"
  (interactive "fSeleccione un archivo: ")
  (let ((dir default-directory))
    (if (and (file-exists-p (expand-file-name "pyproject.toml" dir)) (file-exists-p (expand-file-name "README.md" dir)) (file-exists-p (expand-file-name "main.py" dir)))
       (progn
	(start-process-shell-command "uv-project-run" "*uv-project-run*" (concat "uv run " archivo))
          (with-current-buffer "*uv-project-run*"
               (setq-local comint-prompt-read-only t)
               (setq-local comint-use-prompt-regexp t)
               (setq-local comint-prompt-regexp "^[^#$%>\n]*[#$%>] *")
               (setq-local comint-move-point-for-output 'this)
                (comint-mode))
          (split-window-below)
          (other-window 1)
	  (switch-to-buffer "*uv-project-run*"))
       (message "Los archivos que indicas no son validos necesito archivos python y que se use el gestor de proyectos UV"))))
(use-package uv-mode
  :hook (python-mode . uv-mode-auto-activate-hook))

(use-package geiser
  :ensure t)

(use-package geiser-guile  ;; Si usas Guile Scheme
  :ensure t)
  (use-package flymake-guile
    :defer t)

(use-package rust-mode) ;; Rust

(use-package cargo-mode
    :defer t
    :hook
    (rust-mode . cargo-minor-mode)    
    :config
    (setq compilation-scroll-output t))

(use-package lua-mode)

;;  (use-package lsp-java :config (add-hook 'java-mode-hook 'lsp))
  (use-package eglot-java
    :defer t)

 (add-hook 'java-mode-hook 'eglot-java-mode)

 (with-eval-after-load 'eglot-java
    (define-key eglot-java-mode-map (kbd "C-c l n") #'eglot-java-file-new)
    (define-key eglot-java-mode-map (kbd "C-c l x") #'eglot-java-run-main)
    (define-key eglot-java-mode-map (kbd "C-c l t") #'eglot-java-run-test)
    (define-key eglot-java-mode-map (kbd "C-c l N") #'eglot-java-project-new)
    (define-key eglot-java-mode-map (kbd "C-c l T") #'eglot-java-project-build-task)
    (define-key eglot-java-mode-map (kbd "C-c l R") #'eglot-java-project-build-refresh))
  (use-package flymake-gradle
    :defer t)

(use-package iedit
  :ensure t)
(global-set-key (kbd "C-v") 'iedit-mode)

(use-package dape
  :defer t)

(use-package projectile
  :ensure t
  :config
  (projectile-mode +1))

(setopt projectile-project-root-files '(".git"))

;; (use-package treesit-auto
;;   :config
;;   (global-treesit-auto-mode))
(setq-default treesit-extra-load-path (list (no-littering-expand-var-file-name "tree-sitter/")))

(add-to-list 'treesit-language-source-alist
        '(hyprlang "https://github.com/tree-sitter-grammars/tree-sitter-hyprlang"))

(use-package rainbow-delimiters
  :hook ((emacs-lisp-mode . rainbow-delimiters-mode)
         (prog-mode . rainbow-delimiters-mode)))

(use-package rainbow-mode
:defer t
:hook ((org-mode . rainbow-mode) (prog-mode . rainbow-mode)))

(use-package flymake
  :ensure t
  :defer t
  :hook
  (prog-mode . flymake-mode))

(use-package flymake-flycheck
  :ensure t
  :defer t
  :hook
  (flymake-mode-hook . flymake-flycheck-auto))
(with-eval-after-load 'flymake-mode
  (define-key flymake-mode-map (kbd "M-n") #'flymake-goto-next-error))

(provide 'config)
;;; config.el ends here
