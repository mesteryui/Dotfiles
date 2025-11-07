;; -*- lexical-binding: t; -*- 
(use-package vterm
  :defer t
  :init
  (setq vterm-max-scrollback 10000)
  (setq vterm-buffer-name-string "vterm: %s")
  (setq vterm-toggle-fullscreen-p nil)
  :bind
  (:map
   vterm-mode-map
   ("C-y" . vterm-yank)
   ("C-q" . vterm-send-next-key))
  :config
  (defun mester-vterm-project ()
    (interactive)
    (let ((default-directory (project-root (project-current t))))
      (vterm-toggle)))
  (add-hook 'vterm-mode-hook
	    (lambda ()
	      (face-remap-add-relative 'default '(:family "JetBrainsMono Nerd Font" :height 110)))))
(use-package vterm-toggle
  :bind (("C-c g" . vterm-toggle))
  :config
  (add-to-list 'display-buffer-alist
	       '("\*vterm\*"
		 (display-buffer-in-side-window)
		 (window-height . 0.5)
		 (side . bottom)
		 (slot . 0))))

(provide 'vterm-term)
;;; vterm-term.el ends here

