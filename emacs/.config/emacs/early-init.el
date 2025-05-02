(setq package-enable-at-startup nil) ;; Desactivamos el gestor de paquetes de Emacs para poder usar elpaca
(setq byte-compile-warnings '(not obsolete))
(setq warning-suppress-log-types '((comp) (bytecomp)))
(setq native-comp-async-report-warnings-errors 'silent)
(setenv "LSP_USE_PLISTS" "true")
(setq frame-inhibit-implied-resize t)
;; Garbage collector optimization
(setopt gc-cons-percentage 1.0
	gc-cons-threshold most-positive-fixnum)
(setopt comp-deferred-compilation t)
(setopt comp-async-jobs-number 8)
(provide 'early-init)
