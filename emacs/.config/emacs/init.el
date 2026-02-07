;; -*- lexical-binding: t; -*-

;; 1. Bootstrapping del gestor de paquetes
(load (expand-file-name "modules/core/os-package.el" user-emacs-directory))

;; 2. Cargar el cargador de módulos (Moon Loader)
(use-package moon-loader
  :ensure nil
  :load-path "os-lisp/moon-loader/"
  :config
  ;; 3. Cargar el núcleo (CORE) - El orden importa aquí
  (moon-loader-add-modules
   (os-funcs :after os-macros)
   os-vars    ;; Variables básicas y configuración nativa
   os-defbinds
   )

  ;; 4. Interfaz de Usuario (UI)
  (moon-loader-add-modules
   os-ui
   os-icons
   os-modeline
   )
  
  ;; 5. Otros módulos (se añadirán conforme se creen)
  (moon-loader-add-modules
   ;; Completion
   os-orderless
   os-vertico
   os-marginalia
   os-consult
   os-embark
   os-which-key
   os-corfu
   os-tempel
   os-programming
   os-editing
   
   ;; Tools/UI
   os-dashboard
   os-org
   os-spelling
   ;; Multiple tools
   os-vterm
   os-no-distraction
   os-ligatures
   os-treesit
   os-tramp
   os-eat
   os-git
   os-eshell
   os-productivity
   os-eldoc
   os-docker

   ;; Languages
   os-common-lisp
   os-config-modes
   os-emacs-lisp
   os-golang
   os-hyprlang
   os-java
   os-javascript
   os-kdl
   os-lua
   os-markdown
   os-nim
   os-python
   ;;os-qml
   ;;os-ruby
   os-rune
   os-rust
   os-scheme
   os-systemd
   os-toml
   os-typst
   os-zig
   ))

(provide 'init)
;;; init.el ends here
