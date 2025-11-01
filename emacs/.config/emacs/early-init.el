;; -*- lexical-binding: t; -*-
(setq package-enable-at-startup nil) ;; Desactivamos el gestor de paquetes de Emacs para poder usar elpaca

(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(undecorated . t) default-frame-alist)

(setq byte-compile-warnings '(not obsolete))
(setq warning-suppress-log-types '((comp) (bytecomp)))
(setq native-comp-async-report-warnings-errors 'silent)

(when (featurep 'native-compile)
  (setq native-comp-deferred-compilation t
        native-comp-async-jobs-number 8))

(setenv "LSP_USE_PLISTS" "true")

(setq frame-inhibit-implied-resize t
      frame-resize-pixelwise t)
;; Garbage collector optimization
(setopt gc-cons-percentage 1.0
	gc-cons-threshold most-positive-fixnum)
(provide 'early-init)
