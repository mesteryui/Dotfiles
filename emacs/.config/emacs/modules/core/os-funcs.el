;;; os-funcs.el --- Custom utility functions -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: lisp, tools

;;; Commentary:
;; This file contains general utility functions used in the configuration
;; and for interactive use.

;;; Code:

(require 'os-macros)

(defun os/reload-config ()
  "Reload the Emacs configuration (init.el).
Also re-processes Elpaca queues."
  (interactive)
  (load-file (expand-file-name "init.el" user-emacs-directory))
  (sleep-for 0.90)
  (if (eq major-mode 'org-mode) (org-mode))
  (ignore (elpaca-process-queues)))
(gbind "C-c r" os/reload-config)

(defun os/open-config ()
  "Open the Emacs configuration file (init.el)."
  (interactive)
  (find-file (expand-file-name "init.el" user-emacs-directory)))
(gbind "C-x c" os/open-config)

(defun append-to-list (list-var elements)
  "Append ELEMENTS to the end of LIST-VAR.
The return value is the new value of LIST-VAR.
This modifies the list in place."
  (unless (consp elements)
    (error "ELEMENTS must be a list"))
  (let ((list (symbol-value list-var)))
    (if list
        (setcdr (last list) elements)
      (set list-var elements)))
  (symbol-value list-var))

(defun prot/keyboard-quit-dwim ()
  "Do-What-I-Mean behaviour for a general `keyboard-quit'.
- If region is active, disable it.
- If completion buffer is open, close it.
- If minibuffer is open but not focused, abort recursive edit.
- Otherwise, standard `keyboard-quit'."
  (interactive)
  (cond
   ((region-active-p)
    (keyboard-quit))
   ((derived-mode-p 'completion-list-mode)
    (delete-completion-window))
   ((> (minibuffer-depth) 0)
    (abort-recursive-edit))
   (t
    (keyboard-quit))))

(define-key global-map (kbd "C-g") #'prot/keyboard-quit-dwim)

(provide 'os-funcs)
;;; os-funcs.el ends here
