(add-to-list 'load-path "~/.config/emacs/scripts/")

;;(require 'no-littering-setup) ;; No littering
(require 'elpaca-setup)  ;; The Elpaca Package Manager
;(require 'app-launchers)

(use-package gcmh
  :config
  (setopt gcmh-high-cons-threshold (* 256 1000 1000))
  (setopt gcmh-low-cons-threshold (* 16 1000 1000))
  (setopt gcmh-idle-delay 3)
  ;; (setopt gcmh-verbose t)  
 ; Para ver mensajes de depuración
  (setopt gc-cons-percentage 0.2)
  (add-hook 'elpaca-after-init-hook #'gcmh-mode))

(setq user-full-name "Oscar")
  (setq inhibit-startup-message t
        use-short-answers t)
    (tool-bar-mode -1)                                            ; Desactivar la barra de herramientas
    (menu-bar-mode -1)                                            ; Desactivar la barra de menús
    (scroll-bar-mode -1)                                          ; Desactivar la barra de desplazamiento visible
    (add-to-list 'default-frame-alist '(fullscreen . maximized))
(setq
 display-time-24hr-format t              ; Muestra el reloj en formato 24 hrs
 display-time-format "%H:%M"             ; Le da formato a la hora
 load-prefer-newer t                     ; Prefiere la versión más reciente de un archivo.
 select-enable-clipboard t               ; Sistema de fusión y portapapeles de Emacs.
 vc-follow-symlinks t                    ; Siempre sigue los enlaces simbólicos.
 make-backup-files nil                   ; No realiza backups de ficheros
 auto-save-default nil                   ; Deshabilita #file#
;; org-footnote-section "Referencias:"  ; cambio footnotes por referencias
 ;; global-hl-line-mode t                ; Highlight current line
 kill-ring-max 128                       ; Longitud máxima del anillo de matar
 create-lockfiles nil                    ; Impido la creación de ficheros .#
 )

(defun os/reload-config ()
  "Recargar configuracion Emacs"
  (interactive)
  (load-file "~/.config/emacs/init.el")
  (ignore (elpaca-process-queues)))
(global-set-key (kbd "C-c r") 'os/reload-config)

(set-face-attribute 'default nil
  :font "JetBrains Mono NerdFont"
  :height 102
  :weight 'medium)
(set-face-attribute 'variable-pitch nil
  :font "Ubuntu"
  :height 105
  :weight 'medium)
(set-face-attribute 'fixed-pitch nil
  :font "JetBrains Mono NerdFont"
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

(defun os/open-config ()
  "Abrir configuracion de emacs"
  (interactive)
  (find-file "~/.config/emacs/README.org"))
(global-set-key (kbd "C-x r c") 'os/open-config)

(setq calendar-month-name-array
      ["Enero" "Febrero" "Marzo" "Abril" "Mayo" "Junio"
       "Julio"    "Agosto"   "Septiembre" "Octubre" "Noviembre" "Diciembre"])

(setq calendar-day-name-array
      ["Domingo" "Lunes" "Martes" "Miércoles" "Jueves" "Viernes" "Sábado"])

(setq org-icalendar-timezone "Europe/Madrid") ;; timezone
(setq calendar-week-start-day 1) ;; la semana empieza el lunes
(setq european-calendar-style t) ;; estilo europeo

(use-package catppuccin-theme
    :config
    (setq catppuccin-flavor 'mocha)
    (catppuccin-reload)
    (load-theme 'catppuccin :no-confirm))

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
(setq org-agenda-files '("~/org/agenda.org"))
(setq org-archive-location "~/org/%s_archivo.org::datetree/")
(setq org-todo-keywords
     '((sequence "TODO(t)" "NEXT(n)" "WAITING(w)" "|" "DONE(d)" "CANCELLED(c)")))
 (setq org-todo-keyword-faces
        '(("TODO" . "coral")
          ("NEXT" . "cyan")
          ("PROJ" . "orange")
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

(require 'org-utilities)
  (use-package org-auto-tangle
    :defer t
:hook (org-mode . org-auto-tangle-mode))

(use-package toc-org
    :demand t
    :commands toc-org-enable
    :init (add-hook 'org-mode-hook 'toc-org-enable))

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
(defun pp-switch-dictionary()
  "Switch between Dutch and Australian dictionaries."
  (interactive)
  (let* ((dic ispell-current-dictionary)
         (change (if (string= dic "es_ES") "eo" "es_ES")))
    (ispell-change-dictionary change)
    (message "Dictionary switched from %s to %s" dic change)))

(global-set-key (kbd "M-<f7>") 'pp-switch-dictionary)
  (use-package flyspell-correct
    :after (flyspell)
    :bind (("C-;" . flyspell-auto-correct-previous-word)
           ("<f7>" . flyspell-correct-wrapper)))

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

;  (add-to-list 'load-path "~/.config/emacs/plugins")
  ;  (require 'organizer)
  ;  (global-set-key (kbd "C-c o") 'org-agenda-open-link)
    ;;(load-file "~/.config/emacs/plugins/organizer.el")
  ; 
(use-package organizer
  :demand t
  :ensure (:host codeberg :repo "mester/Organizer")
  :config
   (global-set-key (kbd "<f12>")  'organizer-index))

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

(use-package doom-modeline
    :init (doom-modeline-mode 1)
    :config
    (setq doom-modeline-height 29      ;; sets modeline height
          doom-modeline-bar-width 5    ;; sets right bar width
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

(use-package company
  :defer t
  :ensure t
  :custom
  (company-idle-delay 0.0)
  (company-minimum-prefix-length 1)
  (company-selection-wrap-around t)
  :config
  (global-company-mode t))
(use-package company-box
  :ensure t
  :defer t
  :after company
  :hook (company-mode-hook . company-box-mode))
(use-package company-posframe
  :config
  (company-posframe-mode 1))

;; use-package with package.el:
(use-package dashboard
 :ensure t 
 :init
 (setq initial-buffer-choice 'dashboard-open)
 (setq dashboard-set-heading-icons t)
 (setq dashboard-set-file-icons t)
 (setq dashboard-banner-logo-title "Bienvenido a Emacs")
 ;;(setq dashboard-startup-banner 'logo) ;; use standard emacs logo as banner
 (setq dashboard-startup-banner "~/.config/emacs/image.png")  ;; use custom image as banner
 (setq dashboard-center-content nil) ;; set to 't' for centered content
 (setq dashboard-items '((recents . 5)
                         (agenda . 5 )
                         (bookmarks . 3)))
 :custom 
 (dashboard-modify-heading-icons '((recents . "file-text")
                                     (bookmarks . "book")))
 :config
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

(use-package which-key
  :defer t
  :config
  (which-key-mode)
  (setq which-key-idle-delay 0.3))

(use-package i3wm-config-mode
  :demand t
  :ensure t
  :config
  (add-to-list 'auto-mode-alist '("/sway/.*config.*/" . i3wm-config-mode))
(add-to-list 'auto-mode-alist '("/sway/config\\'" . i3wm-config-mode)))

(use-package fish-mode
  :ensure t
  :demand t)

(use-package transient)
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

(use-package undo-tree
:init
(global-undo-tree-mode 1)
:custom
(undo-tree-visualizer-timestamps t)
(undo-tree-visualizer-diff t)
(undo-tree-auto-save-history nil))

(use-package autorevert
:ensure nil
:diminish
:hook (after-init . global-auto-revert-mode))

(use-package flycheck
:ensure t
:defer t
:init (global-flycheck-mode))
(use-package flycheck-pos-tip
  :ensure t
  :defer t
  :hook
  (flycheck-mode . flycheck-pos-tip-mode))

(use-package savehist
  :ensure nil
  :init
  (savehist-mode))

(use-package vterm
  :defer t
:bind
(:map
 vterm-mode-map
 ("C-y" . vterm-yank)
 ("C-q" . vterm-send-next-key)))
(use-package vterm-toggle)
(global-set-key (kbd "C-c g") 'vterm-toggle)

(use-package calfw
  :config
  (setq cfw:org-overwrite-default-keybinding t)) ;; atajos de teclado de la agenda org-mode
;; (setq cfw:display-calendar-holidays nil) ;; para esconder fiestas calendario emacs

(use-package calfw-org
  :ensure t
  :config
  (setq cfw:org-overwrite-default-keybinding t)
  :bind ([f8] . cfw:open-org-calendar))

(use-package embark
    :bind
    (("C-." . embark-act)
     ("C-:" . embark-dwim)
     ("C-h B" . embark-bindings)))

(use-package embark-consult
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;       (use-package eshell
;         :ensure nil)
;       (use-package eshell-toggle
;       :ensure t
;       :custom
;     (eshell-toggle-size-fraction 3))

;       (use-package eshell-syntax-highlighting
;         :after esh-mode
;         :config
;         (eshell-syntax-highlighting-global-mode +1))
;       (global-set-key (kbd "C-c t") 'eshell-toggle)

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

(use-package jsonrpc
  :defer t
  )
(use-package flymake
  :defer t 
  :config
  (add-hook 'prog-mode-hook #'flymake-mode))
(use-package flymake-gradle)

(use-package eldoc
    :defer t
    :after elpaca)
  (use-package eldoc-box
    :ensure t
    :defer t
    :after eldoc
    :init (setq eldoc-box-hover-mode t))

(use-package lua-mode)

;(require 'eglot-setup)
    (use-package lsp-mode
      :init
      ;; set prefix for lsp-command-keymap (few alternatives - "C-l", "C-c l")
      (setq lsp-keymap-prefix "C-c l")

      :hook (;; replace XXX-mode with concrete major-mode(e. g. python-mode)
             (python-mode . lsp)
             (java-mode . lsp)
             (nxml-mode . lsp)
             (lua-mode . lsp)
             ;; if you want which-key integration
             (lsp-mode . lsp-enable-which-key-integration))
      :custom
       (lsp-completion-enable t)
      :commands lsp)

(use-package lsp-pyright
  :ensure t
  :custom (lsp-pyright-langserver-command "pyright") ;; or basedpyright
  :hook (python-mode . (lambda ()
                          (require 'lsp-pyright)
                          (lsp))))  ; or lsp-deferred
  (use-package lsp-java
    :after lsp
  :ensure t
  :init
  (setq lsp-java-args '("-Dlsp.server.hover.content=ALL")))
    ;; optionally
    (use-package lsp-ui :commands lsp-ui-mode)

(use-package yasnippet
  :defer t
  :config
  ;(add-hook 'lsp-mode #'yas-minor-mode)
  (yas-global-mode t))
(use-package yasnippet-snippets)

(use-package typescript-mode
:demand t
:ensure t)
(add-to-list 'auto-mode-alist '("\.ts\'" . typescript-mode))
(add-to-list 'auto-mode-alist '("\.tsx\'" . typescript-mode))
(add-hook 'typescript-mode 'eglot-typescript-mode)

; (add-hook 'python-mode 'eglot-python-mode)

;(use-package eglot-java
;            :defer t
;            :after eglot)
  
;        (add-hook 'java-mode-hook 'eglot-java-mode)
;            (with-eval-after-load 'eglot-java
;                  (define-key eglot-java-mode-map (kbd "C-c l n") #'eglot-java-file-new)
;                  (define-key eglot-java-mode-map (kbd "C-c l x") #'eglot-java-run-main)
;                  (define-key eglot-java-mode-map (kbd "C-c l t") #'eglot-java-run-test)
;                  (define-key eglot-java-mode-map (kbd "C-c l N") #'eglot-java-project-new)
;                  (define-key eglot-java-mode-map (kbd "C-c l T") #'eglot-java-project-build-task)
;                  (define-key eglot-java-mode-map (kbd "C-c l R") #'eglot-java-project-build-refresh))

(add-hook 'nxml-mode 'eglot-nxml-mode)

(use-package dape
  :defer t)

(add-hook 'prog-mode-hook 'display-line-numbers-mode)

(use-package rainbow-delimiters
  :hook ((emacs-lisp-mode . rainbow-delimiters-mode)
         (clojure-mode . rainbow-delimiters-mode)
         (prog-mode . rainbow-delimiters-mode)))

(use-package rainbow-mode
:defer t
:hook org-mode prog-mode)

(use-package sudo-edit)

(use-package adaptive-wrap
  :config
  (adaptive-wrap-prefix-mode))

(global-set-key [escape] 'keyboard-escape-quit)

(electric-pair-mode t)

(use-package eradio
  :defer t
:init
(setq eradio-player '("mpv" "--no-video" "--no-terminal" "--force-seekable"))
:config
(setq eradio-channels '(("MGT Radio" . "https://stream.zeno.fm/koq3futfevouv")
                        ("Radio asiatica" . "https://stream.zeno.fm/vwvzwtapjrpvv")
)))

(use-package tldr
  :demand t)

(add-to-list 'default-frame-alist '(alpha-background . 92)) ; For all new frames henceforth
