;;; os-tempel.el --- Tempel configuration -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: completion, templates

;;; Commentary:
;; Configuration for Tempel (templates).

;;; Code:

(use-package tempel
  :bind (("M-+" . tempel-complete) ;; o el keybinding que prefieras
         ("M-*" . tempel-insert))
  :custom
  (tempel-path "~/.config/emacs/templates.el") ;; o donde quieras tus plantillas
  :init
  (defun tempel-setup-capf ()
    ;; Add the Tempel Capf to `completion-at-point-functions'.
    ;; `tempel-expand' only triggers on exact matches. Alternatively use
    ;; `tempel-complete' if you want to see all matches, but then you
    ;; should also configure `tempel-trigger-prefix', such that Tempel
    ;; does not trigger too often when you don't expect it. NOTE: We add
    ;; `tempel-expand' *before* the main programming mode Capf, such
    ;; that it will be tried first.
    (setq-local completion-at-point-functions
                (cons #'tempel-expand (cons #'tempel-complete
                                            completion-at-point-functions))))
  :hook ((conf-mode prog-mode text-mode org-mode eglot-managed-mode) . tempel-setup-capf)
  :config 
  (define-key tempel-map (kbd "TAB") #'tempel-next))

(use-package tempel-collection :ensure t :after tempel)

(provide 'os-tempel)
;;; os-tempel.el ends here
