;; -*- lexical-binding: t; -*-
(setopt user-full-name "Oscar")
(setopt inhibit-startup-message t
	use-short-answers t
	blink-matching-parent t)

(gbind-multiple
 ("C-+" . text-scale-increase)
 ("C--" . text-scale-decrease))

(load custom-file 'noerror 'nomessage)

(setq initial-scratch-message (format ";; This is `scratch` buffer. Use `%s` for eval and print the result of expression or also you can use `C-x C-e` for eval lisp expressions in any buffer.Enjoy doing things here.\n\n"
				      (propertize
				       (substitute-command-keys "\\<lisp-interaction-mode-map>\\[eval-print-last-sexp]")
				       'face 'help-key-binding)))

(setopt
 display-time-24hr-format t             ; Muestra el reloj en formato 24 hrs
 display-time-format "%H:%M"             ; Le da formato a la hora
 auto-save-default nil                 ; Deshabilita #file#
 ;;auto-save-visited-interval 3
 load-prefer-newer t                     ; Prefiere la versión más reciente de un archivo.
 select-enable-clipboard t               ; Sistema de fusión y portapapeles de Emacs.
 vc-follow-symlinks t                    ; Siempre sigue los enlaces simbólicos.
 make-backup-files nil                   ; No realiza backups de ficheros
 frame-resize-pixelwise t ;; Para un resize fluido
 select-enable-primary t)
;;(auto-save-visited-mode 1)
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
(provide 'personal)
