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

(use-package eldoc
  :ensure nil
  :hook (prog-mode . eldoc-mode)
  :custom
  (eldoc-documentation-strategy 'eldoc-documentation-compose-eagerly)
  (eldoc-message-function #'message)
  (eldoc-idle-delay 0.2))

(elpaca-wait)

(defgroup mester nil
  "Group to my custom configs"
  :group 'convenience)

(defvar mest-languages '(("Español" . "es_ES") ("English" . "en") ("Esperanto" . "eo"))
  "The languages to be used by word corrections")

(defcustom mester/spell-checker 'jinx
  "Sistema de correccion ortografica de preferencia."
  :type '(choice (const :tag "Jinx" jinx)
  		 (const :tag "Flyspell" flyspell)))
(defcustom mester/modeline 'doom-modeline
  "Modeline por defecto"
  :group 'mester
  :type '(choice (const :tag "Os modeline (Own)" os-modeline)
  		 (const :tag "Doom Modeline" 'doom-modeline)))
;;(setq mester/modeline 'os-modeline)
(defcustom mester/enabled-modules nil
  "Lista de modulos a cargar."
  :group 'mester
  :type '(repeat symbol))

;; Añadir el directorio 'modules' y subdirectorios al 'load-path'
(defun mester/add-subdirs-to-load-path (parent-dir)
  "Añade PARENT-DIR y todos sus subdirectorios al load-path recursivamente."
  (let ((default-directory parent-dir))
    (add-to-list 'load-path parent-dir)
    (normal-top-level-add-subdirs-to-load-path)))
(mester/add-subdirs-to-load-path 
 (expand-file-name "modules/" user-emacs-directory))

;; Lista de módulos a cargar. Comenta o elimina los que no quieras.
(setq mester/enabled-modules
      '(macros      ;; Macros personalizadas
	performance ;; Ajustes del rendimiento
	personal    ;; Ajustes personales diversos
	settings    ;; Ajustes diversos
	ui          ;; Apariencia y UI
	functions   ;; Funciones propias desarrolladas por mi
	org-config  ;; Configuración de Org Mode
	modeline
	tools       ;; Herramientas generales
	keybindings ;; atajos de teclado diversos
	emacs-git
	;; Completion functions
	orderless-funcs
	eldoc-tools
	corfu-completion ;; Sistema de autocompletado
	vertico-funcs ;; Sistema para la completacion del minibuffer
	embark-funcs
	marginalia-funcs
	consult-func
	tempel-funcs
	ligatures
	plz-http
	;; Final Completion Functions
	;; Editing and spelling
	editing
	spelling
	;; End of editing and spelling
	dired
	eat-term
	vterm-term
	tramp-config
	packages    ;; Paquetes que utilizble
	sin-distracciones ;; Modo sin distracciones
	treesit-funcs
	programming ;; Configuraciones base de programación
	;; Módulos de lenguajes específicos
	javascript
	golang
	;; schemelang ;; Lenguaje Scheme
	emacs-lisp ;; Paquetes para facilitar el desarrollo en Emacs Lisp
	pythonlang ;; Lo puse así porque si lo ponia como python hacia conflicto con la libreria de Emacs
	ruby
	systemd-lang
	rune-lang
	zig-lang
	rust
	qml
	hyprlang
	nimlang
	common-lisp ;; Soporte para CommonLisp NOTE Estandar Lisp
	java ;; Lenguaje de programacion Java
	))
;; Cargar los módulos habilitados
(dolist (module mester/enabled-modules)
  (unless (featurep module)
    (require module)))

(provide 'init)
;;; init.el ends here
