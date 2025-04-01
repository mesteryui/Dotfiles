(add-to-list 'load-path "~/.config/emacs/scripts/")

(require 'elpaca-setup)  ;; The Elpaca Package Manager

(require 'various-settings) ;; Ajustes varios

(use-package catppuccin-theme
    :config
    (setq catppuccin-flavor 'mocha)
    (catppuccin-reload)
    (load-theme 'catppuccin :no-confirm))

(set-face-attribute 'default nil
  :font "Jetbrains Mono"
  :height 102
  :weight 'medium)
(set-face-attribute 'variable-pitch nil
  :font "Ubuntu"
  :height 105
  :weight 'medium)
(set-face-attribute 'fixed-pitch nil
  :font "Jetbrains Mono"
  :height 102
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
(add-to-list 'default-frame-alist '(font . "JetBrains Mono NerdFont-10"))

;; Uncomment the following line if line spacing needs adjusting.
(setq-default line-spacing 0.11)

(add-to-list 'default-frame-alist '(alpha-background . 92)) ; For all new frames henceforth

(electric-pair-mode t)

(setq erc-nick "mester")
(setq erc-prompt-for-password (string-trim (shell-command-to-string "cat ~/Descargas/Conjuntos\ contraseña/password_irc")))

(setq user-full-name "Oscar")
  (setq inhibit-startup-message t
        use-short-answers t)
    (tool-bar-mode -1)                                            ; Desactivar la barra de herramientas
    (menu-bar-mode -1)                                            ; Desactivar la barra de menús
    (scroll-bar-mode -1)                                          ; Desactivar la barra de desplazamiento visible
    (add-to-list 'default-frame-alist '(fullscreen . maximized))

(setq
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

(setq calendar-month-name-array
      ["Enero" "Febrero" "Marzo" "Abril" "Mayo" "Junio"
       "Julio"    "Agosto"   "Septiembre" "Octubre" "Noviembre" "Diciembre"])

(setq calendar-day-name-array
      ["Domingo" "Lunes" "Martes" "Miércoles" "Jueves" "Viernes" "Sábado"])

(setq org-icalendar-timezone "Europe/Madrid") ;; timezone
(setq calendar-week-start-day 1) ;; la semana empieza el lunes
(setq european-calendar-style t) ;; estilo europeo

(setq calendar-holidays '(
			  (holiday-fixed 1 1 "Año nuevo")
			  (holiday-fixed 5 17 "Dia de las letras gallegas")
			  (holiday-fixed 10 12 "Día de la Hispanidad")
                          (holiday-fixed 11 01 "Todos los Santos")
			  (holiday-fixed 12 06 "Constitución")
			  (holiday-fixed 3 28 "Reconquista de Vigo")
			  (holiday-fixed 5 1 "Dia del Trabajo")
			  (holiday-fixed 12 24 "Nochebuena")
			  (holiday-fixed 12 25 "Navidad")
			  ))

(setq gc-cons-threshold 100000000)
(setq read-process-output-max (* 1024 1024))

(defun os/reload-config ()
  "Recargar configuracion Emacs"
  (interactive)
  (load-file "~/.config/emacs/init.el")
  (ignore (elpaca-process-queues)))
(global-set-key (kbd "C-c r") 'os/reload-config)

(defun os/open-config ()
  "Abrir configuracion de emacs"
  (interactive)
  (find-file "~/.config/emacs/README.org"))
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
  "Function to toggle a not much bigger webserver ChatGPT helping me to fix some things"
  (interactive)
  (let ((proc (get-process "webserver")))
    (if (and proc (eq (process-status proc) 'run))  ;; Verifica si el proceso está corriendo
        (progn
          (delete-process "webserver")
          (message "Webserver stopped"))
      (progn
        (start-process "webserver" "*webserver*" "npx" "browser-sync" "start" "--server" "--files" "**/*")
        (message "Webserver started")))))

(setq org-return-follows-link  t)

(use-package org
    :ensure nil
    :defer t)
    (require 'org-tempo)
      (setq-default org-startup-indented t
                    org-pretty-entities t
                    org-use-sub-superscripts "{}"
                    org-hide-emphasis-markers t
                    org-startup-with-inline-images t
                    image-actual-width '(300))
(add-hook 'org-mode-hook 'org-indent-mode)
    ;; Mostrar marcadores de énfasis ocultos
  (setq org-directory "~/org/")
  (setq org-agenda-files '("~/org/agenda.org" "~/org/proyectos.org"))
  (setq org-archive-location "~/org/%s_archivo.org::datetree/")
  (setq org-todo-keywords
       '((sequence "TODO(t)" "NEXT(n)" "WAITING(w)" "PROJ(p)" "PAUSED(p)" "|" "DONE(d)" "CANCELLED(c)")))
   (setq org-todo-keyword-faces
          '(("TODO" . "coral")
            ("NEXT" . "cyan")
            ("PROJ" . "orange")
	    ("WAITING" . "yellow")
            ("DONE" . "green")
            ("PAUSED" . "IndianRed1")
            ("CANCELLED" . "grey")))
        (global-set-key (kbd "C-c c") 'org-capture)
        (global-set-key (kbd "C-c a") 'org-agenda)
          (setq org-export-with-drawers nil
                org-export-with-todo-keywords nil
                org-export-with-broken-links t
                org-export-with-toc nil
                org-export-with-smart-quotes t
                org-export-date-timestamp-format "%d %B %Y"
                org-list-allow-alphabetical t)

(setq org-capture-templates
       `(("t" "Tarea" entry
          (file+headline "~/org/agenda.org" "Tareas")
          "* TODO %?\n  Creado: %U\n  %i\n  %a")
         ("n" "Nota" entry
          (file+headline "~/org/notes.org" "Notas")
          "* %? :nota:\n  Creado: %U\n  %i\n  %a")
	  ("e" "Evento" entry
	   (file+headline "~/org/agenda.org" "Evento")
	   "* WAITING %?\n"
	   )
         ("j" "Diario" entry
          (file+datetree "~/org/diario.org")
          "* %?\nCreado: %U\n")
	   ("p" "Project" entry
          (file+headline "~/org/proyectos.org" "Proyectos")
          "* PROJ %?\n")
	  )
	  )

(org-babel-do-load-languages
 'org-babel-load-languages
 '((scheme . t)
   ))

(use-package org-auto-tangle
    :defer t
:hook (org-mode . org-auto-tangle-mode))

(use-package geiser
  :ensure t)

(use-package geiser-guile  ;; Si usas Guile Scheme
  :ensure t)

(require 'org-utilities)

(use-package toc-org
    :demand t
    :commands toc-org-enable
    :init (add-hook 'org-mode-hook 'toc-org-enable))

(use-package nerd-icons
  ;; :custom
  ;; The Nerd Font you want to use in GUI
  ;; "Symbols Nerd Font Mono" is the default and is recommended
  ;; but you can use any other Nerd Font if you want
  ;; (nerd-icons-font-family "Symbols Nerd Font Mono")
  )
(use-package nerd-icons-dired
  :hook
  (dired-mode . nerd-icons-dired-mode))
(use-package nerd-icons-completion
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))

(use-package calfw
  :config
  (setq cfw:org-overwrite-default-keybinding t)) ;; atajos de teclado de la agenda org-mode
  (setq cfw:display-calendar-holidays t) ;; para esconder fiestas calendario emacs

(use-package calfw-org
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
(use-package vterm-toggle)
(global-set-key (kbd "C-c g") 'vterm-toggle)

;; ;; Aun no soportado en la shell de comandos que uso
(use-package eat
  :ensure t
  :defer t)

(use-package dired-sidebar
    :ensure t
    :defer t
    :commands (dired-sidebar-toggle-sidebar)
    :init
    (setq dired-sidebar-theme 'nerd)
    (setq dired-sidebar-use-term-integration t)
    (setq dired-sidebar-use-custom-font t))

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
	  :init
      (eat-eshell-mode t))
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
      (setq ispell-silently-savep t
        flyspell-case-fold-duplications t
        flyspell-issue-message-flag nil
        flyspell-default-dictionary "es_ES"
        ispell-program-name "hunspell")
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

(use-package treemacs)
(global-set-key (kbd "C-c f") 'treemacs)

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
 :init
 (setq initial-buffer-choice 'dashboard-open)
 (setq dashboard-set-heading-icons t)
 (setq dashboard-display-icons-p t)
 (setq dashboard-set-file-icons t)
 (setq dashboard-set-heading-icons t)
 (setq dashboard-set-file-icons t)
 (setq dashboard-vertically-center-content t)
 (setq dashboard-banner-logo-title (format "Bienvenido a Emacs %s, %s" emacs-version (capitalize (user-login-name))))
 ;;(setq dashboard-startup-banner 'logo) ;; use standard emacs logo as banner
 (setq dashboard-startup-banner "~/.config/emacs/images/kawaii-sm.png")  ;; use custom image as banner
 (setq dashboard-center-content nil) ;; set to 't' for centered content
  (setq dashboard-modify-heading-icons '((recents . "file-text")
                                     (bookmarks . "book")))
 (setq dashboard-items '((recents . 5)
                         (agenda . 5 )
                         (bookmarks . 3)))
 :config
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
    :init (doom-modeline-mode 1)
    :config
    (setq doom-modeline-height 27      ;; sets modeline height
          doom-modeline-bar-width 10    ;; sets right bar width
          doom-modeline-persp-name t   ;; adds perspective name to modeline
          doom-modeline-persp-icon t)) ;; adds folder icon next to persp name

(use-package vertico
  :init
  (vertico-mode)
  :custom
  (vertico-count 13)                    ; Número de candidatos a mostrar
  (vertico-resize t)
  (vertico-cycle t)
  (vertico-sort-function 'vertico-sort-history-alpha))
;; Use vertico posframe cuando use EXWM, o cuando use un tiling window manager a pantalla completa
;;(use-package vertico-posframe)

(use-package marginalia
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
(global-set-key (kbd "C-c o") 'consult-org-agenda)

(use-package which-key
  :defer t
  :config
  (which-key-mode)
  (setq which-key-idle-delay 0.3))

(use-package organizer
  :demand t
  :ensure (:host codeberg :repo "mester/Organizer")
  :config
  (global-set-key (kbd "<f12>")  'organizer-index)
  (add-to-list 'organizer-files '("Libros" . "~/org/Libros.org")))

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
  (setq eradio-player '("mpv" "--no-video" "--no-terminal" "--force-seekable"))
  :config
  (setq eradio-channels '(("MGT Radio" . "https://stream.zeno.fm/koq3futfevouv") ;Esto con el punto se usa para crear un par asi podemos extraer uno u otro
                        ("Radio asiatica" . "https://stream.zeno.fm/vwvzwtapjrpvv")
			("Radio Libretics" . "https://stream-170.zeno.fm/a79lrhms108uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJhNzlscmhtczEwOHV2IiwiaG9zdCI6InN0cmVhbS0xNzAuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IndQLS1ld3VYVGV5RjcxNUtmaXdMRkEiLCJpYXQiOjE3NDIxNTQ3NzIsImV4cCI6MTc0MjE1NDgzMn0.nR6YeM5BOcjVXbKfFaSLO6v_kLFFvdgnbGRtaO_UblY")
			)))
(global-set-key (kbd "C-x r e") 'eradio-toggle)
(global-set-key (kbd "C-x r p") 'eradio-play)

(use-package transient)

(use-package doc-view
  :demand t
 :ensure nil
 :custom
(doc-view-resolution 300)
(doc-view-mupdf-use-svg t)
(large-file-warning-threshold (* 50 (expt 2 20))))

(use-package nov
  :demand t
:init
(add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode)))

(use-package typst-mode
  :ensure (:type git :host github :repo "Ziqi-Yang/typst-mode.el"))

(use-package elfeed
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

(use-package markdown-mode
  :demand t
:commands (markdown-mode gfm-mode)
:mode (("README\\.md\\'" . gfm-mode)
       ("\\.md\\'" . gfm-mode)
       ("\\.markdown\\'" . markdown-mode))
:init (setq markdown-command "markdown2")
:config
(setq visual-line-column 80)
(setq markdown-fontify-code-blocks-natively t)
(setq markdown-enable-math t))

(use-package super-save
  :config
  (setq super-save-triggers
  '(other-window  ; Al cambiar de ventana
    switch-to-buffer  ; Al cambiar de buffer
    mouse-leave-buffer-hook)) ; Al mover el ratón fuera de Emacs
  (super-save-mode 1)
  (setq super-save-idle-duration 0.3)  ; 0.3 segundos de inactividad
  (setq super-save-auto-save-when-idle t)) ; Opcional: guardar también en inactividad

(use-package adaptive-wrap
  :config
  (adaptive-wrap-prefix-mode))

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

(use-package elpy
    :ensure t
    :defer t
    :config
    (setq python-shell-interpreter "python3")
    (setq elpy-rpc-python-command "python3")
    :init
    (advice-add 'python-mode :before 'elpy-enable))

(use-package flycheck-pycheckers)

(use-package flycheck-pos-tip
  :ensure t
  :defer t
  :hook
  (flycheck-mode . flycheck-pos-tip-mode))

(use-package magit
   :bind
   ("C-x g" . magit-status))

 (use-package git-gutter
   :defer 0.3
   :delight
   :init (global-git-gutter-mode))

 (use-package git-timemachine
   :defer 1
   :delight)

(use-package eldoc-box
  :ensure t
  :defer t
  :after eldoc
  :init (setq eldoc-box-hover-mode t))

(use-package company
  :init
  (global-company-mode)
  :config
  (setq company-minimum-prefix-length 1
        company-idle-delay 0.0))
(use-package company-posframe
    :after company
    :config
    (company-posframe-mode t)
    :delight " C-PF")
  (use-package company-box
    :ensure t
    :defer t
    :after company
    :delight " CBox"
    :hook (company-mode-hook . company-box-mode))

(use-package yasnippet
  :defer t)
(add-hook 'org-mode-hook 'yas-minor-mode)
(add-hook 'prog-mode-hook 'yas-minor-mode)
(use-package yasnippet-snippets)

(use-package lsp-mode
    :init
    ;; set prefix for lsp-command-keymap (few alternatives - "C-l", "C-c l")
    (setq lsp-keymap-prefix "C-c l")
    :hook (;; replace XXX-mode with concrete major-mode(e. g. python-mode)
           (rust-mode . lsp)
  	       (mhtml-mode . lsp)
           ;; if you want which-key integration
           (lsp-mode . lsp-enable-which-key-integration)
  	       (python-mode . lsp)
  	       (js-mode . lsp))
    :commands lsp)
  (use-package lsp-java :config (add-hook 'java-mode-hook 'lsp))
  (use-package lsp-pyright
  :ensure t
  :custom (lsp-pyright-langserver-command "pyright") ;; or basedpyright
  :hook (python-mode . (lambda ()
                          (require 'lsp-pyright)
                          (lsp))))  ; or lsp-deferred

;; optionally
(use-package lsp-ui :commands lsp-ui-mode)

(use-package rust-mode) ;; Rust

(use-package cargo-mode
    :defer t
    :hook
    (rust-mode . cargo-minor-mode)    :config
    (setq compilation-scroll-output t))

(use-package lua-mode)

(use-package flymake-gradle
  :defer t)

(use-package java-snippets
  :defer t)

(use-package projectile
  :init (projectile-mode +1)
  :bind-keymap ("C-c p" . projectile-command-map))

(use-package treesit-auto
  :config
  (global-treesit-auto-mode))

(use-package rainbow-delimiters
  :hook ((emacs-lisp-mode . rainbow-delimiters-mode)
         (clojure-mode . rainbow-delimiters-mode)
         (prog-mode . rainbow-delimiters-mode)))

(use-package rainbow-mode
:defer t
:hook org-mode prog-mode)

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

(provide 'init)
