;; -*- lexical-binding: t; -*-

;; =============================================================================
;; PAQUETES
;; =============================================================================
(setq package-enable-at-startup nil
      package-quickstart nil)

;; =============================================================================
;; COMPILACIÓN NATIVA Y ADVERTENCIAS
;; =============================================================================
(setq byte-compile-warnings '(not obsolete))
(setq warning-suppress-log-types '((comp) (bytecomp)))
(setq native-comp-async-report-warnings-errors 'silent)

(when (featurep 'native-compile)
  (setq native-comp-speed 2
        native-comp-deferred-compilation t
        native-comp-async-jobs-number 8))

;; =============================================================================
;; CONFIGURACIÓN DE LA INTERFAZ DE USUARIO (UI)
;; =============================================================================
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(horizontal-scroll-bars) default-frame-alist)

(setq frame-inhibit-implied-resize t
      frame-resize-pixelwise t)

(setq inhibit-compacting-font-caches t)

;; =============================================================================
;; OPTIMIZACIONES DE ARRANQUE
;; =============================================================================

;; Preferir archivos .elc más nuevos
(setq load-prefer-newer t)

;; Deshabilitar manejador de archivos automático durante el inicio
(setq auto-mode-case-fold nil)

;; Optimización del recolector de basura
(setopt gc-cons-percentage 0.5
	gc-cons-threshold most-positive-fixnum)

;; Aumentar el límite de salida del proceso de lectura
(setq read-process-output-max (* 1024 1024)) ;; 1MB

;; Almacenar file-name-handler-alist por defecto y restaurar después del inicio
(defvar default-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

;; Deshabilitar el control de versiones durante el inicio
(defvar default-vc-handled-backends vc-handled-backends)
(setq vc-handled-backends nil)

;; =============================================================================
;; CONFIGURACIONES ESPECÍFICAS DEL SISTEMA
;; =============================================================================
(when (featurep 'pgtk)
  (setq pgtk-wait-for-event-timeout 0.001))

(setenv "LSP_USE_PLISTS" "true")

;; =============================================================================
;; HOOK DE ARRANQUE DE EMACS
;; =============================================================================
(add-hook 'emacs-startup-hook
          (lambda ()
            ;; Restaurar la configuración del recolector de basura (umbral de 16MB)
            
            ;; Restaurar el manejador de nombres de archivo
            (setq file-name-handler-alist default-file-name-handler-alist)
            
            ;; Restaurar los backends de control de versiones
            (setq vc-handled-backends default-vc-handled-backends)
            
            ;; Recolectar basura al perder el foco (opcional pero útil)
            (add-function :after after-focus-change-function
                          (lambda ()
			    (unless (frame-focus-state)
			      (garbage-collect))))

	    ))

(provide 'early-init)
