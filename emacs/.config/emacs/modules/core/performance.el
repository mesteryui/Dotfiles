;; -*- lexical-binding: t; -*-
(setq jit-lock-stealth-time 0.5)
(setq jit-lock-chunk-size 1000)
(setq jit-lock-defer-time nil)

(use-package gcmh
  :init
  (setq gc-cons-threshold (* 64 1024 1024)) ;; Seteando los ajustes por defecto del recolector de basura
  (setq gcmh-idle-delay 'auto  ; default is 15s
	gcmh-auto-idle-delay-factor 10 ;; Factor usado para decidir cuanto espera el recolector de basura cuando no has estado usando el editor
	gcmh-high-cons-threshold (* 128 1024 1024))
  :ensure t
  :hook (elpaca-after-init-hook . gcmh-mode))

(global-so-long-mode 1)
(os/after so-long
	  (when (boundp 'so-long-minor-modes)
	    (add-to-list 'so-long-minor-modes 'display-line-numbers-mode)
	    (add-to-list 'so-long-minor-modes 'hl-line-mode))

	  ;; Only add mode replacements if the variable exists
	  (when (boundp 'so-long-action-alist)
	    (setq so-long-action-alist
		  (append so-long-action-alist
			  '(("disable-indicator" . ((display-fill-column-indicator-mode . -1))))))))
(provide 'performance)
