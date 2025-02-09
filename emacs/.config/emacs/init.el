(add-to-list 'load-path "~/.config/emacs/scripts/")

;;(require 'no-littering-setup) ;; No littering
(require 'elpaca-setup)  ;; The Elpaca Package Manager
(require 'various-settings)
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
           "* %?\nCreado: %U\n")))

(global-set-key (kbd "C-c o") 'consult-org-agenda)

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
  :hook (lsp-mode . company-mode)
  :custom
  (company-idle-delay 0.1)
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
;; (use-package auto-save
;;   :config
;;   (auto-save-enable)
;;   (setq auto-save-idle 0.3)   ; Guarda tras 0.3 segundos sin teclear
;;   (setq auto-save-silent t)   ; Sin mensajes molestos
;;   (setq auto-save-delete-trailing-whitespace t) ; Limpia espacios al guardar
;; )
(use-package super-save
  :config
  (setq super-save-triggers
  '(other-window  ; Al cambiar de ventana
    switch-to-buffer  ; Al cambiar de buffer
   ; ace-window  ; Si usas ace-window
    mouse-leave-buffer-hook)) ; Al mover el ratón fuera de Emacs
  (super-save-mode 1)
  (setq super-save-idle-duration 0.3)  ; 0.3 segundos de inactividad
  (setq super-save-auto-save-when-idle t)) ; Opcional: guardar también en inactividad
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

;; Configuracion de programacion
(use-package lua-mode)


(use-package lsp-mode
  :ensure t
  :hook
  ;; Activar automáticamente para lenguajes soportados
  ((java-mode python-mode xml-mode html-mode) . lsp)
  :config
  ;; Configuración general
  (setq lsp-keymap-prefix "C-c l"          ;; Prefijo para atajos de lsp-mode
        lsp-enable-snippet t              ;; Activar snippets
        lsp-enable-on-type-formatting t   ;; Formatear mientras escribes
        lsp-headerline-breadcrumb-enable t)) ;; Mostrar ruta de archivo en el encabezado

;; Soporte adicional para UI (opcional)
(use-package lsp-ui
  :ensure t
  :hook (lsp-mode . lsp-ui-mode)
  :config
  ;; Configuración de pop-ups y documentos flotantes
  (setq lsp-ui-doc-enable t               ;; Mostrar documentación flotante
        lsp-ui-doc-position 'at-point     ;; Mostrar cerca del cursor
        lsp-ui-sideline-enable t          ;; Información en la línea lateral
        lsp-ui-sideline-show-code-actions t))

;; Flycheck para errores en tiempo real
(use-package flycheck
  :ensure t
  :hook (lsp-mode . flycheck-mode))

;; Instalación de iconos opcionales para breadcrumbs
(use-package lsp-treemacs
  :ensure t
  :config
  (lsp-treemacs-sync-mode 1)) ;; Sincronizar la vista de proyectos con Treemacs

;; Soporte para formateo de código con lsp
;(use-package lsp-format
;  :after lsp-mode
;  :hook (before-save . lsp-format-buffer)) ;; Formatear al guardar

(use-package lsp-java
  :ensure t
  :after lsp
  :config
  (add-hook 'java-mode-hook #'lsp-java-lens-mode)) ;; Añade soporte para LSP en Java
(use-package lsp-pyright
  :ensure t
  :hook (python-mode . (lambda ()
                         (require 'lsp-pyright)
                         (lsp)))) ;; Inicia LSP para Python

;; Configuracion
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

;(add-hook 'nxml-mode 'eglot-nxml-mode)


(add-hook 'prog-mode-hook 'display-line-numbers-mode)

(use-package treemacs)
(global-set-key (kbd "C-c f") 'treemacs)

(use-package projectile
  :ensure t
  :init
  (projectile-mode +1)
  :config
  (setq projectile-project-search-path '("~/Proyectos"))
  :bind (:map projectile-mode-map
              ("C-c p" . projectile-command-map)))
(defun crear-proyecto-gradle (nombre)
  "Crea un nuevo proyecto Gradle con el NOMBRE dado."
  (interactive "sNombre del proyecto: ")
  (let ((directorio (concat (file-name-as-directory "~/Proyectos/") nombre)))
    (make-directory directorio t)
    (shell-command (format "gradle init --type java-application -p %s" directorio))
    (find-file (concat directorio "/build.gradle"))
    (message "Proyecto Gradle creado en %s" directorio)))
(defun crear-proyecto-maven (nombre)
  "Crea un nuevo proyecto Maven con el NOMBRE dado."
  (interactive "sNombre del proyecto: ")
  (let ((directorio (concat (file-name-as-directory "~/Proyectos/") nombre)))
    (make-directory directorio t)
    (shell-command (format "mvn archetype:generate -DgroupId=com.example -DartifactId=%s -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false -DoutputDirectory=%s" nombre directorio))
    (find-file (concat directorio "/" nombre "/pom.xml"))
    (message "Proyecto Maven creado en %s" directorio)))

(defun crear-proyecto-python (nombre)
  "Crea un nuevo proyecto Python con un entorno virtual venv."
  (interactive "sNombre del proyecto: ")
  (let* ((directorio (concat (file-name-as-directory "~/Proyectos/") nombre))
         (venv-path (concat directorio ".venv")))
    ;; Crear el directorio del proyecto
    (make-directory directorio t)
    ;; Crear el entorno virtual
    (shell-command (format "python3 -m venv %s" venv-path))
    ;; Crear un archivo main.py por defecto
    (with-temp-file (concat directorio "/main.py")
      (insert "#!/usr/bin/env python3\n\n"
              "def main():\n"
              "    print('Hello, World!')\n\n"
              "if __name__ == '__main__':\n"
              "    main()"))
    ;; Abrir el proyecto en Emacs
    (find-file (concat directorio "/main.py"))
    ;; Activar el entorno virtual automáticamente
    (pyvenv-activate venv-path)
    (message "Proyecto Python creado en %s con entorno virtual en %s" directorio venv-path)))

(use-package rainbow-delimiters
  :hook ((emacs-lisp-mode . rainbow-delimiters-mode)
         (clojure-mode . rainbow-delimiters-mode)
         (prog-mode . rainbow-delimiters-mode)))

(use-package rainbow-mode
:defer t
:hook org-mode prog-mode)

(use-package sudo-edit)

(use-package typst-mode
  :ensure (:type git :host github :repo "Ziqi-Yang/typst-mode.el"))

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
