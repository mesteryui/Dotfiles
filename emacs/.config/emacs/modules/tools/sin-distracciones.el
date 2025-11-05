;; -*- lexical-binding: t; -*-
(use-package olivetti
  :commands (olivetti-mode)
  :config 
  (setq olivetti-minimum-body-width 80
	olivetti-recall-visual-line-mode-entry-state t))

(use-package logos
  :ensure t
  :bind
  (("C-x n n" . logos-narrow-dwim)
   ("C-x ]" . logos-forward-page-dwim)
   ("C-x [" . logos-backward-page-dwim)
   ;; I don't think I ever saw a package bind M-] or M-[...
   ("M-]" . logos-forward-page-dwim)
   ("M-[" . logos-backward-page-dwim)
   ("<f9>" . logos-focus-mode))
  :config
  (setq logos-outlines-are-pages t)
  (setq logos-outline-regexp-alist
        `((emacs-lisp-mode . ,(format "\\(^;;;+ \\|%s\\)" logos-page-delimiter))
          (org-mode . ,(format "\\(^\\*+ +\\|^-\\{5\\}$\\|%s\\)" logos-page-delimiter))
          (markdown-mode . ,(format "\\(^\\#+ +\\|^[*-]\\{5\\}$\\|^\\* \\* \\*$\\|%s\\)" logos-page-delimiter))
          (conf-toml-mode . "^\\[")))
  (setq-default logos-hide-mode-line t)
  (setq-default logos-hide-header-line t)
  (setq-default logos-hide-buffer-boundaries t)
  (setq-default logos-hide-fringe t)
  (setq-default logos-variable-pitch t)
  (setq-default logos-buffer-read-only nil)
  (setq-default logos-scroll-lock nil)
  (setq-default logos-olivetti t)

  (add-hook 'enable-theme-functions #'logos-update-fringe-in-buffers))
(provide 'sin-distracciones)
