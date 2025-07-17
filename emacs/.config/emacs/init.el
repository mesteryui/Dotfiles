;; -*- lexical-binding: t; -*-
;;(add-to-list 'load-path "~/.config/emacs/scripts/")

(defvar no-littering-etc-directory (expand-file-name "~/.local/share/emacs/etc/"))
(defvar no-littering-var-directory (expand-file-name "~/.local/share/emacs/var/"))

(when (boundp 'native-comp-eln-load-path)
  (startup-redirect-eln-cache (expand-file-name "eln-cache" no-littering-var-directory)))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;(setq elpaca-core-date '(20250223)) ;; set to the build date of Emacs
(defvar elpaca-installer-version 0.11)
(defvar elpaca-directory (expand-file-name "elpaca/"  no-littering-var-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (< emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                 ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                 ,@(when-let ((depth (plist-get order :depth)))
                                                     (list (format "--depth=%d" depth) "--no-single-branch"))
                                                 ,(plist-get order :repo) ,repo))))
                 ((zerop (call-process "git" nil buffer t "checkout"
                                       (or (plist-get order :ref) "--"))))
                 (emacs (concat invocation-directory invocation-name))
                 ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                       "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                 ((require 'elpaca))
                 ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (load "./elpaca-autoloads")))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))
;;(elpaca org)
(elpaca elpaca-use-package
  ;; Enable :elpaca use-package keyword.
  (elpaca-use-package-mode)
  ;; Assume :elpaca t unless otherwise specified.
  (setq elpaca-use-package-by-default t))

;; Block until current queue processed.
(use-package no-littering
  :ensure t
  :init
  ;; set paths for no-littering etc and var directories
  ;; instead of this paths, you could use
  ;; (setq user-emacs-directory (expand-file-name "~/.cache/emacs"))
  (setq no-littering-etc-directory (expand-file-name "~/.local/share/emacs/etc/")
        no-littering-var-directory (expand-file-name "~/.local/share/emacs/var/")
      )
  :config
  ;; set sensible defaults for backups
  (no-littering-theme-backups)
  ;; set paths for url-history-file and custom-file
  (setopt url-history-file (no-littering-expand-etc-file-name "url/history")
        custom-file (no-littering-expand-etc-file-name "custom-vars.el"))
 )
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(elpaca-wait)
;;When installing a package which modifies a form used at the top-level
;;(e.g. a package which adds a use-package key word),
;;use `elpaca-wait' to block until that package has been installed/configured.
;;For example:
;;(use-package general :demand t)
;;(elpaca-wait)

;;Turns off elpaca-use-package-mode current declartion
;;Note this will cause the declaration to be interpreted immediately (not deferred).
;;Useful for configuring built-in emacs features.
;;(use-package emacs :elpaca nil :config (setq ring-bell-function #'ignore))

;; Don't install anything. Defer execution of BODY
;;(elpaca nil (message "deferred"))

(defvar os-languages '(("Español" . "es_ES") ("English" . "en") ("Esperanto" . "eo"))
  "The languages to be used by word corrections")
(defvar my/enabled-modules nil
"Lista de modulos a cargar.")

;; Añadir el directorio 'lisp' y subdirectorios al 'load-path'
(add-to-list 'load-path (expand-file-name "lisp/" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "lisp/lang/" user-emacs-directory))

;; Lista de módulos a cargar. Comenta o elimina los que no quieras.
(setq my/enabled-modules
  '(macros      ;; Macros personalizadas
    performance ;; Ajustes del rendimiento
    personal    ;; Ajustes personales diversos
    ui          ;; Apariencia y UI
    functions   ;; Funciones propias desarrolladas por mi
    org-config  ;; Configuración de Org Mode
    tools       ;; Herramientas generales
    packages    ;; Paquetes que utilizo
    completion ;; Cosas de autocompletado
    programming ;; Configuraciones base de programación
    ;; Módulos de lenguajes específicos
    javascript
    scheme
    emacs-lisp ;; Desarrollo de paquetes para Emacs
    pythonlang ;; Lo puse así porque si lo ponia como python hacia conflicto con la libreria de Emacs
    rust
    common-lisp
    lua
    java))
;; Cargar los módulos habilitados
(dolist (module my/enabled-modules)
  (unless (featurep module)
  (require module)))

(provide 'init)
;;; init.el ends here
