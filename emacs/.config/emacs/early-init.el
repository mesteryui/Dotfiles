(setq package-enable-at-startup nil) ;; Desactivamos el gestor de paquetes de Emacs para poder usar elpaca
(setq byte-compile-warnings '(not obsolete))
(setq warning-suppress-log-types '((comp) (bytecomp)))
(setq native-comp-async-report-warnings-errors 'silent)
(setenv "LSP_USE_PLISTS" "true")
(setopt gc-cons-threshold 100000000)
(setq read-process-output-max (* 4 1024 1024))
;; Garbage collector optimization
(setopt gcmh-idle-delay 5)
(setopt gcmh-high-cons-threshold (* 1024 1024 1024))
(setopt comp-deferred-compilation t)
(setopt comp-async-jobs-number 8)
(provide 'early-init)
