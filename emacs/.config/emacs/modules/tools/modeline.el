;; -*- lexical-binding: t; -*- 

(use-package doom-modeline
  :if (eq mester/modeline 'doom-modeline)
  :after (nerd-icons)
  :hook (elpaca-after-init-hook . doom-modeline-mode)
  :config
  ;;(setq doom-modeline-height 20) 
  (setq doom-modeline-window-width-limit 90)
  (setq doom-modeline-project-detection 'auto)
  (setq doom-modeline-modal-modern-icon t))

(use-package os-modeline
  :if (eq mester/modeline 'os-modeline)
  :load-path "os-lisp/"
  :custom (os-modeline-bar-height 25)
  :config
  (setq mode-line-compact nil) ; Emacs 28
  (setq mode-line-right-align-edge 'right-margin) ; Emacs 30
  (setq-default mode-line-format
		'("%e"
		  os-modeline-input-method
                  os-modeline-kbd-macro
                  os-modeline-buffer-status
	          os-modeline-buffer-name
                  "   "
                  os-modeline-major-mode
		  "   "
		  os-modeline-zoom
                  "   "
                  (:eval (when (buffer-file-name) "%p"))
                  "   "
                  os-modeline-vc-branch
		  "   "
		  os-modeline-eglot
		  "   "
                  os-modeline-flymake
                  "   "
		  mode-line-format-right-align ; Emacs 30
		  os-modeline-misc-info)))

(provide 'modeline)
;;; modeline.el ends here
