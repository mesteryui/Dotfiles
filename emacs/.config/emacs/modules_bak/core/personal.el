;;; personal.el --- Personal Identity and Basic Settings -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: configuration, personal

;;; Commentary:
;; This file contains user identity settings (name, email) and
;; basic Emacs behavior configurations like startup messages,
;; backups, and calendar settings.

;;; Code:

;; User Identity
(setopt user-full-name "Oscar")
(setopt erc-nick "mester")

;; Passwords and Auth
(setq erc-prompt-for-password (string-trim (shell-command-to-string "cat ~/Descargas/Conjuntos\ contraseña/password_irc")))

;; UI Defaults
(setopt inhibit-startup-message t
        use-short-answers t
        blink-matching-parent t)

(setopt display-time-24hr-format t             ; Muestra el reloj en formato 24 hrs
        display-time-format "%H:%M"             ; Le da formato a la hora
        frame-resize-pixelwise t               ; Para un resize fluido
        frame-inhibit-implied-resize t)        ; Evita glitches al redimensionar

;; Editing Behavior
(setopt select-enable-clipboard t               ; Sistema de fusión y portapapeles de Emacs.
        select-enable-primary t
        enable-local-variables t
        vc-follow-symlinks t)                   ; Siempre sigue los enlaces simbólicos.

;; Files and Backups
(setopt load-prefer-newer t                     ; Prefiere la versión más reciente de un archivo.
        auto-save-default nil                   ; Deshabilita #file#
        make-backup-files nil)                  ; No realiza backups de ficheros

(add-hook 'elpaca-after-init-hook (lambda () (load custom-file 'noerror 'nomessage)))

;; Scratch Buffer
(setq initial-scratch-message (format ";; This is `scratch` buffer. Use `%s` for eval and print the result of expression or also you can use `C-x C-e` for eval modules expressions in any buffer. Enjoy doing things here.\n\n"
                                      (propertize
                                       (substitute-command-keys \"<\lisp-interaction-mode-map>\[eval-print-last-sexp]\"")
                                       'face 'help-key-binding)))

;; ERC Settings
(setq erc-track-enable-keybindings t)
(setopt erc-fill-column 120
        erc-fill-function 'erc-fill-static
        erc-fill-static-center 20)

;; Calendar Configuration
(setopt calendar-week-start-day 1) ;; la semana empieza el lunes
(setopt calendar-date-style 'iso)
;; (setq european-calendar-style t) ;; estilo europeo

(setopt calendar-holidays '((holiday-fixed 1 1 "Año nuevo")
                            (holiday-fixed 5 17 "Dia de las letras gallegas")
                            (holiday-fixed 10 12 "Día de la Hispanidad")
                            (holiday-fixed 11 01 "Todos los Santos")
                            (holiday-fixed 12 06 "Constitución")
                            (holiday-fixed 3 28 "Reconquista de Vigo")
                            (holiday-fixed 5 1 "Dia del Trabajo")
                            (holiday-fixed 12 24 "Nochebuena")
                            (holiday-fixed 12 25 "Navidad")))

(provide 'personal)
;;; personal.el ends here
