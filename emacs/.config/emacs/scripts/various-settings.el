
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


(setq calendar-month-name-array
      ["Enero" "Febrero" "Marzo" "Abril" "Mayo" "Junio"
       "Julio"    "Agosto"   "Septiembre" "Octubre" "Noviembre" "Diciembre"])

(setq calendar-day-name-array
      ["Domingo" "Lunes" "Martes" "Miércoles" "Jueves" "Viernes" "Sábado"])

(setq org-icalendar-timezone "Europe/Madrid") ;; timezone
(setq calendar-week-start-day 1) ;; la semana empieza el lunes
(setq european-calendar-style t) ;; estilo europeo

(provide 'various-settings)


