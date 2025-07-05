;;; -*- lexical-binding: t; -*-
;;(add-to-list 'org-src-lang-modes '("emacs-lisp" . emacs-lisp))

(setq jit-lock-stealth-time 0.5)
(setq jit-lock-chunk-size 1000)
(setq jit-lock-defer-time 0.05)

(use-package gcmh
  :init 
  (setq gc-cons-threshold (* 16 1024 1024)) ;; Seteando los ajustes por defecto del recolector de basura
  (setq gcmh-idle-delay 'auto  ; default is 15s
      gcmh-auto-idle-delay-factor 10 ;; Factor usado para decidir cuanto espera el recolector de basura cuando no has estado usando el editor
      gcmh-high-cons-threshold (* 64 1024 1024))
  :ensure t
  :hook (elpaca-after-init-hook . gcmh-mode))

(defmacro loadf (file) `(load-file ,file))

(defmacro os/add-to-list (list &rest elements)
   `(progn ,@(seq-map (lambda (e) `(add-to-list ',list ,e)) elements)))

(defmacro os/after (package &rest body)
"Execute the code after the load of a package if the package is loaded the code is executed directly if not the package will be charged, first the PACKAGE you want to verifyis loaded to execute code after that BODY is the code to execute."
`(if (featurep ',package)
     (progn ,@body)
     (with-eval-after-load ',package
        ,@body)))

(defmacro when-system (system &rest body)
  "Ejecuta BODY solo si estamos en SYSTEM (gnu/linux, darwin, windows-nt)"
  `(when (eq system-type ',system)
     ,@body))

(defmacro gbind (key func)
"Asigna atajos de teclado globales de forma más sencilla usando kbd:
KEY: Es el conjunto de teclas FUNC: Es la funcion que queremos asignar al atajo"
`(global-set-key (kbd ,key) ',func))

(defmacro unbind (key)
  "Unbind the global KEY sequence."
  `(global-unset-key (kbd ,key)))

(defmacro add-hooks (hook &rest funcs)
"Añadir varias funciones a un hook
Es decir si tengo org-mode-hook puedo añadir varias funciones
siendo HOOK el hook que quiero añadir
y FUNCS las funciones a añadir"
`(progn ,@(seq-map (lambda (f) `(add-hook ',hook ,f)) funcs)))

(use-package mixed-pitch
:ensure t
:hook (text-mode . mixed-pitch-mode)
:config 
(add-to-list 'mixed-pitch-fixed-pitch-faces 'org-table
))

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

(use-package catppuccin-theme
  :config 
   (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'catppuccin t))

(add-to-list 'initial-frame-alist '(fullscreen . maximized)) ;; Empezar maximizado
(add-to-list 'default-frame-alist '(undecorated . t))
(tool-bar-mode -1)                                            ; Desactivar la barra de herramientas
(menu-bar-mode -1)                                            ; Desactivar la barra de menús
(scroll-bar-mode -1)                                          ; Desactivar la barra de desplazamiento visible
(tooltip-mode -1)
(pixel-scroll-precision-mode t)
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

(defun my/certain-use-fixed-pitch ()
  "Usar fuente monoespaciada en ciertos modos."
  (setq buffer-face-mode-face 'fixed-pitch)
  (buffer-face-mode 1))
(add-hook 'mhtml-mode-hook #'my/certain-use-fixed-pitch)
(add-hook 'nxml-mode #'my/certain-use-fixed-pitch)

(add-to-list 'default-frame-alist '(alpha-background . 92)) ; For all new frames henceforth

(electric-pair-mode t)

(setopt erc-nick "mester")
(setq erc-prompt-for-password (string-trim (shell-command-to-string "cat ~/Descargas/Conjuntos\\ contraseña/password_irc")))
(setq erc-track-enable-keybindings t)
(setopt erc-fill-column 120
      erc-fill-function 'erc-fill-static
      erc-fill-static-center 20)

(setopt user-full-name "Oscar")
(setopt inhibit-startup-message t
        use-short-answers t
	blink-matching-parent t)

(gbind "C-+" text-scale-increase)
(gbind "C--" text-scale-decrease)

(setopt
   display-time-24hr-format t             ; Muestra el reloj en formato 24 hrs
   display-time-format "%H:%M"             ; Le da formato a la hora
   auto-save-default nil                   ; Deshabilita #file#
   load-prefer-newer t                     ; Prefiere la versión más reciente de un archivo.
   select-enable-clipboard t               ; Sistema de fusión y portapapeles de Emacs.
   vc-follow-symlinks t                    ; Siempre sigue los enlaces simbólicos.
   make-backup-files nil                   ; No realiza backups de ficheros
   frame-resize-pixelwise t ;; Para un resize fluido
    select-enable-primary t)

(setq enable-local-variables t)

;; Evita glitches al redimensionar
(setq frame-inhibit-implied-resize t)
  ;; org-icalendar-timezone "Europe/Madrid") ;; timezone
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

(global-so-long-mode 1)
(os/after so-long
    (when (boundp 'so-long-minor-modes)
      (add-to-list 'so-long-minor-modes 'display-line-numbers-mode)
      (add-to-list 'so-long-minor-modes 'hl-line-mode))
    
    ;; Only add mode replacements if the variable exists
    (when (boundp 'so-long-action-alist)
      (setq so-long-action-alist
            (append so-long-action-alist
                   '(("disable-indicator" . ((display-fill-column-indicator-mode . -1))))))))

(defun create-uv-project (archivo)
  "Crear un proyecto de uv personalizado y listo para empezar a editar"
  (interactive "GIntroduzca la carpeta del proyecto: ")
  (let ((dir (file-name-as-directory archivo))) ; asegura que termine con /
    (unless (file-directory-p dir)
      (make-directory dir t)
      (message "Carpeta creada: %s" dir))
    (activate-project dir)))

(defun activate-project (dir)
  "Activar un proyecto de uv"
  (let ((default-directory dir))
    (when (fboundp 'uv-init-cmd) ; solo si está definido
      (uv-init-cmd dir))))

(defun os/install-all-treesit-grammars ()
"Install all treesit grammar if it's not installed"
(interactive)
(let ((langs (mapcar 'car treesit-language-source-alist)))
     (dolist (lang langs)
         (unless (treesit-language-available-p lang)
              (message "Instalando gramatica tree-sitter para %s" lang)
              (treesit-install-language-grammar lang)))
          (message "Gramaticas instaladas")))

(defun append-to-list (list-var elements)
  "Append ELEMENTS to the end of LIST-VAR.
	The return value is the new value of LIST-VAR."
  (unless (consp elements)
    (error "ELEMENTS must be a list"))
  (let ((list (symbol-value list-var)))
    (if list
	(setcdr (last list) elements)
      (set list-var elements)))
  (symbol-value list-var))

(defun append-to-gitignore (file)
  "Añade archivos al gitignore"
  (interactive "fSelect a file to append in the gitignore: ")
  (with-current-buffer (find-file-noselect (expand-file-name ".gitignore" doom-modeline--project-root))
    (end-of-buffer)
    (insert (format "\n%s" file))
    (save-buffer)))

(defun get-local-language ()
  "Retrieve the definition the language org variable."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward
           "^#\\+LANGUAGE:[ \t]*\\(.*\\)$" nil t)
      (let ((lang (match-string-no-properties 1)))
	(cond 
	 ((equal lang "es") "es_ES")
	 ((equal lang "en") "en_US")
	 (t lang))))))

(defun dynamic-language-change ()
  "Define the dictionary used locally to apply the word correction,
using what the result of 'get-local-language' function if the result is nil doesn't happen any change in another case use the language returned by 'get-local-language'"
  (when-let ((lang (get-local-language)))
    (setq ispell-local-dictionary lang)))

(defun get-local-macro-definition (macro-name)
  "Retrieve the definition of a local Org mode macro."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (concat "^#\\+MACRO: " macro-name " \\(.*\\)$") nil t)
      (match-string 1))))

(defun os/reload-config ()
  "Recargar configuracion Emacs"
  (interactive)
  (loadf (expand-file-name "init.el" user-emacs-directory))
  (ignore (elpaca-process-queues)))
(gbind "C-c r" os/reload-config)

(defun os/open-config ()
  "Abrir configuracion de emacs"
  (interactive)
  (find-file (expand-file-name "config.org" user-emacs-directory)))
  (gbind "C-x c" os/open-config)

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

(defun org-temp-buffer (&optional template)
   "Acceder a un buffer temporal de orgmode"
   (interactive)
   (switch-to-buffer (get-buffer-create "*orgtemp*"))
   (if (get-buffer "*orgtemp*")
         (progn (insert (format "#+title: %s\n#+description:%s\n#+author: %s\n\n"   (or template "Temporal Buffer")
                     (format-time-string "%Y-%m-%d") user-full-name))
	(org-mode)
        (goto-char (point-max)))))

(setopt org-directory "~/org/")
(setopt diary-file (expand-file-name "diario.org" org-directory))
(setopt org-default-notes-file (expand-file-name "notes.org" org-directory))
(setopt org-agenda-files `( ,(expand-file-name "agenda.org" org-directory) ,(expand-file-name "proyectos.org" org-directory)))
(setopt org-archive-location "~/org/%s_archivo.org::datetree/")

(use-package org
  :ensure nil
  :hook ((org-mode . org-indent-mode)
	 (org-mode . os/org-headers-setters)
         (org-mode . visual-line-mode)
         (org-mode . dynamic-language-change))
  :custom
  ;; Exportación
  (org-export-with-drawers nil)
  (org-export-with-todo-keywords nil)
  (org-export-with-broken-links t)
  (org-export-with-toc nil)
  (org-export-with-smart-quotes t)
  (org-export-date-timestamp-format "%d %B %Y")
  ;; Apariencia
  (org-ellipsis "▼")
  (org-startup-indented t)
  (org-pretty-entities t)
  (org-fontify-done-headline t)
  (org-use-sub-superscripts "{}")
  (org-hide-emphasis-markers t)
  ;; Imágenes
  (org-startup-with-inline-images t)
  (image-actual-width '(300))
  ;; Babel
  (org-confirm-babel-evaluate nil)
  ;; Agenda
  (org-agenda-skip-scheduled-if-done t)
  ;; Listas
  (org-list-allow-alphabetical t)
  ;; Enlaces
  (org-return-follows-link t)
  :config
  (require 'org-tempo))
        (gbind "C-c c" org-capture)
        (gbind "C-c a" org-agenda)

;; disable electric pairing for angle bracket

(add-hook 'org-mode-hook (lambda ()
           (setq-local electric-pair-inhibit-predicate
                   `(lambda (c)
                  (if (char-equal c ?<) t (,electric-pair-inhibit-predicate c))))))

(global-set-key [escape] 'keyboard-escape-quit)

(setopt calendar-month-name-array
      ["Enero" "Febrero" "Marzo" "Abril" "Mayo" "Junio"
       "Julio" "Agosto" "Septiembre" "Octubre" "Noviembre" "Diciembre"])

(setopt calendar-day-name-array
      ["Domingo" "Lunes" "Martes" "Miércoles" "Jueves" "Viernes" "Sábado"])

(setopt org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "WAITING(w)" "PAUSED(P)" "|" "DONE(d)" "CANCELLED(c)")))
    (setopt org-todo-keyword-faces
           '(("TODO" . "coral")
             ("NEXT" . "cyan")
 	        ("WAITING" . "yellow")
             ("DONE" . "green")
             ("PAUSED" . "IndianRed1")
             ("CANCELLED" . "grey")))

(use-package org-wild-notifier
  :ensure t
  :after org
  :custom
  (org-wild-notifier-notification-title "Org Wild Reminder")
  (org-wild-notifier-alert-time (quote(1 10 30 1440 2880)))
  (alert-default-style 'libnotify)
  :config
  (org-wild-notifier-mode 1))

(electric-indent-mode 0)
(setq org-edit-src-content-indentation 0
      org-src-preserve-indentation nil)

(setopt org-src-tab-acts-natively t
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
(use-package htmlize
  :ensure t)

(setq org-capture-templates
        `(("t" "Tarea" entry
           (file+headline "~/org/agenda.org" "Tareas")
           "* TODO %?\n %i\n  %a")
          ("n" "Nota" entry
           (file+headline "~/org/notes.org" "Notas")
           "* %? :nota:\n %i\n %a")
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

(os/after org
(org-babel-do-load-languages
 'org-babel-load-languages
 '((emacs-lisp . t)
   (scheme . t)
   (python . t)
   (shell . t))))
(os/after org-contrib
(org-babel-do-load-languages 'org-babel-load-languages '((ledger . t))))

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
    :custom
    (org-tags-exclude-from-inheritance (quote ("crypt")))
    (org-crypt-key "oscarodriguez56@gmail.com"))

(use-package org-contrib
 :after org)

(use-package gptel
:config
(setq gptel-model 'gemini-2.5-pro 
      gptel-backend (gptel-make-gemini "Gemini" :key (string-trim (shell-command-to-string "pass show geminiAPI")) :stream t)))

(use-package tramp
  :ensure nil
  :custom
  (remote-file-name-inhibit-locks t)
  (tramp-use-scp-direct-remote-copying t)
  (tramp-copy-size-limit (* 1024 1024))
  (tramp-verbose 2)
  (tramp-persistency-file-name
   (no-littering-expand-var-file-name "tramp/history.el"))
  :config 
(connection-local-set-profile-variables
     'remote-direct-async-process
     '((tramp-direct-async-process . t)))
    (connection-local-set-profiles
     '(:application tramp :protocol "ssh")
     'remote-direct-async-process))

(use-package nerd-icons
  :ensure t)
(use-package nerd-icons-completion
  :ensure t
  :after (marginalia nerd-icons)
  :hook (marginalia-mode . nerd-icons-completion-marginalia-setup)
  :init (nerd-icons-completion-mode))

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

(use-package dired 
  :ensure nil 
  :config
 (when-let (cmd (cond ((equal system-type 'darwin) "open")
                       ((equal system-type 'gnu/linux) "xdg-open")
                       ((equal system-type 'windows-nt) "start")))
    (setopt dired-guess-shell-alist-user
          `(("\\.\\(?:docx\\|pdf\\|djvu\\|eps\\)\\'" ,cmd)
            ("\\.\\(?:jpe?g\\|png\\|gif\\|xpm\\)\\'" ,cmd)
            ("\\.\\(?:xcf\\)\\'" ,cmd)
            ("\\.csv\\'" ,cmd)
            ("\\.tex\\'" ,cmd)
            ("\\.\\(?:mp4\\|mkv\\|avi\\|flv\\|rm\\|rmvb\\|ogv\\)\\(?:\\.part\\)?\\'" ,cmd)
            ("\\.\\(?:mp3\\|flac\\)\\'" ,cmd)
            ("\\.html?\\'" ,cmd)
            ("\\.md\\'" ,cmd))))
 (put 'dired-find-alternate-file 'disabled nil))
(use-package dired-x
  :ensure nil
  :hook (dired-mode . dired-omit-mode)
  :config
  ;; Make dired-omit-mode hide all "dotfiles"
    (setq dired-omit-verbose nil)
  (setq dired-omit-files
        (concat dired-omit-files "\\|^\\..*$")))

;; Additional syntax highlighting for dired
(use-package diredfl
  :hook
  ((dired-mode . diredfl-mode)
   ;; highlight parent and directory preview as well
   (dirvish-directory-view-mode . diredfl-mode))
  :config
  (set-face-attribute 'diredfl-dir-name nil :bold t))

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
(global-set-key (kbd "C-c s") #'dirvish-side)

(use-package autorevert
:ensure nil
:diminish
:hook (after-init . global-auto-revert-mode))

;; 
(setq eshell-prompt-function
      (lambda ()
        (let ((status (if (= eshell-last-command-status 0)
                          (propertize "✔" 'face '(:foreground "green"))
                        (propertize "✘" 'face '(:foreground "red")))))
          (concat
	   (propertize (nerd-icons-devicon "nf-dev-emacs" :v-adjust -0.14)  'face '(:foreground "purple" :height 1.5))
	   " "
           (propertize (user-login-name))
           "@"
           (propertize (system-name) 'face '(:foreground "red"))
           " "
           (propertize (abbreviate-file-name (eshell/pwd)) 'face '(:foreground "green"))
           " " status "\n"
           (nerd-icons-faicon "nf-fa-arrow_right_long") " "))))

(defalias 'clean 'eshell/clear-scrollback)

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

(gbind "M-<f7>" dicitionary-switcher)
  (use-package flyspell-correct
    :after (flyspell)
    :bind (("C-;" . flyspell-auto-correct-previous-word)
           ("<f7>" . flyspell-correct-wrapper)))

(use-package vundo
:bind ("C-x u" . vundo))

(use-package treemacs
 :config 
(global-set-key (kbd "C-c d") 'treemacs)
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
    (("C-c a" . embark-act)
     ("C-:" . embark-dwim)
     ("C-h B" . embark-bindings)))

(use-package embark-consult
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;; use-package with package.el:
(use-package dashboard
  :ensure t
  :hook 
  (elpaca-after-init-hook . dashboard-insert-startupify-lists)
  (elpaca-after-init-hook . dashboard-initialize)
  :custom
  (initial-buffer-choice 'dashboard-open) ;; Para que el buffer que aparece por defecto sea el dashboard cosa util si tienes el cliente y abres varias instancias
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
      (,(nerd-icons-mdicon "nf-md-cog" :height 1.1 :v-adjust 0.0) ;; Icono del menu
       "Settings" "Open Config file" ;; Texto en el dashboard y texto cuando pasas el cursor
       (lambda (&rest _) (os/open-config))) ;; Lambda para ejecutar lo que se necesita para acceder a eso
      (,(nerd-icons-flicon "nf-linux-hyprland" :height 1.1 :v-adjust 0.0)
       "WM Settings" "Hyprland settings"
       (lambda (&rest _) (find-file "~/.config/hypr/hyprland.conf")))
      (,(nerd-icons-mdicon "nf-md-notebook" :height 1.1 :v-adjust 0.0)
       "Index" "Index of my Org"
       (lambda (&rest _) (organizer-index))))))
  (dashboard-startupify-list
   '(dashboard-insert-banner ;; Banner
     dashboard-insert-newline ;; Insertando nueva linea
     dashboard-insert-banner-title ;; Insertando banner del titulo
     dashboard-insert-newline
     dashboard-insert-navigator
     dashboard-insert-items
     dashboard-insert-newline
     dashboard-insert-footer
     dashboard-insert-init-info)) ;; Insertando informacion de inicio
  :config
  (dashboard-modify-heading-icons '((recents   . "nf-oct-file")
                                     (projects  . "nf-oct-rocket")
                                     (bookmarks . "nf-oct-bookmark")
                                     (agenda    . "nf-oct-calendar")
                                     (registers . "nf-oct-note")))
  (dashboard-setup-startup-hook))
(gbind "<f10>" open-dashboard)
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
    (doom-modeline-height 30)
    (doom-modeline-bar-width 3)
    (doom-modeline-icon t)
    (doom-modeline-buffer-file-name-style 'file-name) ; solo el nombre del archivo, no ruta completa
(doom-modeline-minor-modes nil)                   ; oculta modos menores
(doom-modeline-enable-word-count nil)
(doom-modeline-buffer-encoding nil))

(use-package ewth
:ensure (:type git :host github :repo "ISouthRain/ewth.el")
:custom (ewth-url "https://wttr.in/Vigo?format=2&M")
:config (ewth-mode))

(use-package vertico
  :init
  (vertico-mode)
  (vertico-multiform-mode)
  :custom
  (vertico-count 15)                    ; Número de candidatos a mostrar
  (vertico-resize t)
  (vertico-cycle t)
  (vertico-sort-function 'vertico-sort-history-alpha)
  :config 
  (add-to-list 'vertico-multiform-categories '(embark-keybinding grid)))
;;(add-to-list 'vertico-multiform-categories '(embark-keybinding grid))

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
  (completion-category-overrides
   '((file (styles basic partial-completion)))))

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
         which-key-ellipsis "…")
(setq prefix-help-command #'embark-prefix-help-command)) ;; Usando esto es posible usar embark para hacer que la busqueda sea más comoda

(use-package organizer
  :demand t
  :ensure nil 
  :load-path "Organizer/"
  :bind ("<f12>" . organizer-index)
  :config
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

(use-package super-save
  :config
  (setopt super-save-triggers
  '(other-window  ; Al cambiar de ventana
    switch-to-buffer  ; Al cambiar de buffer
    mouse-leave-buffer-hook)) ; Al mover el ratón fuera de Emacs
  (super-save-mode 1)
  (setopt super-save-idle-duration 1)  ; 0.3 segundos de inactividad
  (setopt super-save-auto-save-when-idle t)) ; Opcional: guardar también en inactividad

(use-package adaptive-wrap
  :config
  (adaptive-wrap-prefix-mode))

(add-to-list 'auto-mode-alist '("\\.jsonc\\'" . json-ts-mode))

(defun set-markdown-headers () 
   "Setting the headers to a markdown file"
  (set-face-attribute 'markdown-header-face-1 nil :height 2.0)
  (set-face-attribute 'markdown-header-face-2 nil :height 1.75)
  (set-face-attribute 'markdown-header-face-3 nil :height 1.5)
  (set-face-attribute 'markdown-header-face-4 nil :height 1.3)
  (set-face-attribute 'markdown-header-face-5 nil :height 1.15)
  (set-face-attribute 'markdown-header-face-6 nil :height 1.05)
  (set-face-attribute 'markdown-code-face nil :inherit  'fixed-pitch))

(use-package markdown-mode
  :demand t
  :commands (markdown-mode gfm-mode)
  :hook ((markdown-mode . set-markdown-headers)
         (gfm-mode . set-markdown-headers))
  :mode (("README\\.md\\'" . gfm-mode)
       ("\\.md\\'" . gfm-mode)
       ("\\.markdown\\'" . markdown-mode))
  :init (setq markdown-command "markdown2")
  :config
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

(use-package kdl-ts-mode 
  :ensure (:host github :repo "dataphract/kdl-ts-mode"))

(use-package fish-mode
  :ensure t
  :demand t)

(use-package yuck-mode :ensure t)

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

(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :config
  (setq hl-todo-keyword-faces
    '(("FIXME" error bold)
      ("TODO" org-todo)
      ("DONE" org-done)
      ("NOTE" bold))))

(use-package slime
  :custom (inferior-lisp-program "sblc"))

(use-package eglot-tempel
  :preface (eglot-tempel-mode)
  :init
  (eglot-tempel-mode t))

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
  (corfu-auto-delay 0.0)
  (corfu-quit-at-boundary nil)
  (corfu-preselect-first t)  
   (corfu-quit-at-boundary 'separator)
  (corfu-popupinfo-delay '(0.4 . 0.2))
  (corfu-preview-current 'promt) ; insert previewed candidate
  (corfu-on-exact-match nil)
   :hook
    (elpaca-after-init . (lambda ()
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
  (add-hooks completion-at-point-functions #'cape-abbrev #'cape-dabbrev #'cape-file #'cape-emoji #'cape-dict #'cape-keyword #'cape-elisp-block))
;; Atajos prácticos
;;(global-set-key (kbd "M-<tab>") #'completion-at-point) ; TAB para completado

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

(use-package kind-icon
  :after corfu
  :custom (kind-icon-default-face 'corfu-default)
  :config
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

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

(use-package tempel-collection :ensure t)

(use-package eglot
  :ensure nil
  :hook ((prog-mode . eglot-ensure)
         (eglot-managed-mode . eldoc-box-hover-mode))
  :custom
  (eglot-sync-connect 1)
  (eglot-autoshutdown t)
  (eglot-events-buffer-size 0)
  (eglot-auto-display-help-buffer nil)
  (eglot-confirm-server-initiated-edits nil)
  :bind (:map eglot-mode-map
              ("C-c l a" . eglot-code-actions)
              ("C-c l i" . eglot-code-actions-organize-imports)
              ("C-c l r" . eglot-rename)
              ("C-c l f" . eglot-format)
              ("C-c l n" . flymake-next-error)
              ("C-c l p" . flymake-previous-error)
              ("C-c l d" . eldoc))
  :config
  ;; (add-to-list 'eglot-server-programs
  ;;              '((python-mode python-ts-mode) . ("pylsp")))
  ;; (add-to-list 'eglot-server-programs
  ;;              '((c-mode c++-mode) . ("clangd")))
  )

(use-package js
    :ensure nil
    :custom
    (js-indent-level 2)
    :config
    (unbind-key "M-." js-base-mode-map))

(use-package ruby-mode :ensure nil)
(use-package ruby-ts-mode
  :ensure nil
   :mode "\\.rb\\'"
   :mode "Rakefile\\'"
   :mode "Gemfile\\'")

(use-package uv
  :ensure (uv :type git :host github :repo "johannes-mueller/uv.el")
  :init
  (add-to-list 'treesit-language-source-alist '(toml "https://github.com/tree-sitter-grammars/tree-sitter-toml"))
  (unless (treesit-language-available-p 'toml)
    (treesit-install-language-grammar 'toml)))
(use-package tomlparse
  :ensure (:type git :host github :repo "johannes-mueller/tomlparse.el"))

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
;; TODO Do the java programation more useful
 (add-hook 'java-mode-hook 'eglot-java-mode)

 (os/after eglot-java
    (define-key eglot-java-mode-map (kbd "C-c l n") #'eglot-java-file-new)
    (define-key eglot-java-mode-map (kbd "C-c l x") #'eglot-java-run-main)
    (define-key eglot-java-mode-map (kbd "C-c l t") #'eglot-java-run-test)
    (define-key eglot-java-mode-map (kbd "C-c l N") #'eglot-java-project-new)
    (define-key eglot-java-mode-map (kbd "C-c l T") #'eglot-java-project-build-task)
    (define-key eglot-java-mode-map (kbd "C-c l R") #'eglot-java-project-build-refresh))
  (use-package flymake-gradle
    :defer t)

(use-package kotlin-mode
  :ensure t)

(use-package iedit
  :ensure t)
(gbind "C-v" iedit-mode)

(use-package dape
  :defer t
  :custom 
   (dape-buffer-window-arrangement 'right)  ;; o 'bottom si prefieres
   (dape-use-icons t)
   :config
    (global-set-key (kbd "<f5>") #'dape)
  (global-set-key (kbd "<f9>") #'dape-breakpoint-toggle)
  (global-set-key (kbd "<f6>") #'dape-step-over)
  (global-set-key (kbd "<f11>") #'dape-step-in)
  (global-set-key (kbd "S-<f11>") #'dape-step-out))

(use-package projectile
  :ensure t
  :config
  (projectile-mode +1))

(setopt projectile-project-root-files '(".git"))

;; (use-package treesit-auto
;;   :config
;;   (global-treesit-auto-mode))
(setq-default treesit-extra-load-path (list (no-littering-expand-var-file-name "tree-sitter/")))
 (setq treesit-language-source-alist
      '((bash "https://github.com/tree-sitter/tree-sitter-bash")
        (c "https://github.com/tree-sitter/tree-sitter-c")
        (c++ "https://github.com/tree-sitter/tree-sitter-cpp")
        (css "https://github.com/tree-sitter/tree-sitter-css")
        (go "https://github.com/tree-sitter/tree-sitter-go")
        (html "https://github.com/tree-sitter/tree-sitter-html")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript")
        (json "https://github.com/tree-sitter/tree-sitter-json")
        (lua "https://github.com/Azganoth/tree-sitter-lua")
        (php "https://github.com/tree-sitter/tree-sitter-php")
        (python "https://github.com/tree-sitter/tree-sitter-python")
        (ruby "https://github.com/tree-sitter/tree-sitter-ruby")
        (rust "https://github.com/tree-sitter/tree-sitter-rust")
        (toml "https://github.com/tree-sitter/tree-sitter-toml")
        (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
        (yaml "https://github.com/ikatyang/tree-sitter-yaml")))
(add-to-list 'treesit-language-source-alist
        '(hyprlang "https://github.com/tree-sitter-grammars/tree-sitter-hyprlang"))
(setq treesit-font-lock-level 4)  ;; Maximum highlighting
     (setq major-mode-remap-alist
        '((c-mode . c-ts-mode)
          (c++-mode . c++-ts-mode)
          (css-mode . css-ts-mode)
          (js-mode . js-ts-mode)
          (javascript-mode . js-ts-mode)
          (js2-mode . js-ts-mode)
          (typescript-mode . typescript-ts-mode)
          (json-mode . json-ts-mode)
          (python-mode . python-ts-mode)
          (bash-mode . bash-ts-mode)
          (sh-mode . bash-ts-mode)
          (yaml-mode . yaml-ts-mode)
          (go-mode . go-ts-mode)
          (rust-mode . rust-ts-mode)
          (lua-mode . lua-ts-mode)))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package rainbow-mode
:defer t
:hook ((org-mode . rainbow-mode) (prog-mode . rainbow-mode)))

(use-package flymake
    :ensure t
    :defer t
    :hook
    (prog-mode . flymake-mode)
    :config 
(setopt flymake-fringe-indicator-position 'left-fringe)
(setopt flymake-show-diagnostics-at-end-of-line nil)

;; Suppress the display of Flymake error counters when there are no errors.
(setopt flymake-suppress-zero-counters t)

;; Disable wrapping around when navigating Flymake errors.
(setopt flymake-wrap-around nil))

  (use-package flymake-flycheck
    :ensure t
    :defer t
    :hook
    (flymake-mode-hook . flymake-flycheck-auto))
  (with-eval-after-load 'flymake-mode
    (define-key flymake-mode-map (kbd "M-n") #'flymake-goto-next-error))

(provide 'config)
;;; config.el ends here
