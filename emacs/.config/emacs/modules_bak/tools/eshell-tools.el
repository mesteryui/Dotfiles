;;; -*- lexical-binding: t -*-
(setq eshell-prompt-function
      (lambda ()
	(let ((status (if (= eshell-last-command-status 0)
			  (propertize "✔" 'face '(:foreground "green"))
			(propertize "✘" 'face '(:foreground "red")))))
	  (concat
	   (propertize (nerd-icons-devicon "nf-dev-emacs" :v-adjust -0.14)  'face '(:foreground "purple" :height 1.5))
	   " "
	   (propertize (user-login-name))
	   "@"
	   (propertize (system-name) 'face '(:foreground "red"))
	   " "
	   (propertize (abbreviate-file-name (eshell/pwd)) 'face '(:foreground "green"))
	   " " status "\n"
	   (nerd-icons-faicon "nf-fa-arrow_right_long") " "))))

(defun eshell-close-toggle ()
  "Cierra la ventana de eshell."
  (let* ((buf (current-buffer)) (win (get-buffer-window buf)))
    (when (not (eq (selected-window) (next-window)))
      (delete-window win))))
(defun unable-completion-eshell ()
  "Disable completion system in eahell"
  (corfu-mode -1)
  (completion-preview-mode -1))
(use-package eshell
  :ensure nil
  :hook ((eshell-exit . eshell-close-toggle)
	 (eshell-mode . unable-completion-eshell)
	 (eshell-load . eat-eshell-mode)
	 (eshell-load . eat-eshell-visual-command-mode))
  :config
  (defun eshell/clear ()
    (eshell/clear-scrollback))
  (setopt eshell-scroll-to-bottom-on-input 'this   ;; Desplazar abajo al escribir
	  eshell-buffer-maximum-lines 6000     ;; Limitar líneas en el buffer
	  eshell-hist-ignoredups t          ;; Evitar duplicados en el historial
	  eshell-destroy-buffer-when-process-dies t)) ;; Cerrar buffer si el proceso muere
;;(add-hook 'eshell-exit-hook #'eshell-close-toggle) ;; Añadiendo un hook para cerrar la terminal de eshell-toggle
;;(add-hook 'eshell-mode-hook #'unable-corfu-eshell)
(use-package eshell-toggle
  :ensure t
  :after (eshell)
  :custom
  (eshell-toggle-size-fraction 3))
(use-package eshell-syntax-highlighting
  :after esh-mode
  :config
  (eshell-syntax-highlighting-global-mode +1))
(global-set-key (kbd "C-c e") 'eshell-toggle)

(provide 'eshell-tools)
