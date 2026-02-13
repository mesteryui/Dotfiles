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

(defun toggle-webserver ()
  "Toggle a simple webserver (browser-sync) for the current directory.
If running, it stops the server. If stopped, it starts it on port 3000."
  (interactive)
  (let ((proc (get-process "webserver")))
    (if (and proc (eq (process-status proc) 'run))
        (progn
          (delete-process "webserver")
          (message "Webserver stopped"))
      (make-process :name "webserver" 
                    :command '("npx" "browser-sync" "start" "--server" "--files" "**/*") 
                    :buffer "*webserver*"
                    :filter (lambda (_proc output)
                              (when (string-match "Local: http://localhost:3000" output)
                                (message " ✅ Webserver started")))))))

(defun my/python-run-file ()
  "Run the current Python file in its virtual environment (pet)."
  (interactive)
  (when (derived-mode-p 'python-mode 'python-ts-mode)
    (pet-mode 1)
    (save-buffer)
    (let* ((venv (pet-virtualenv-root))
           (python-exe (if venv
                           (expand-file-name "bin/python" venv)
                         "python3"))
           (cmd (format "%s %s" python-exe (shell-quote-argument buffer-file-name))))
      (compile cmd))))

(define-key global-map (kbd "C-g") #'prot/keyboard-quit-dwim)

(provide 'os-funcs)
;;; os-funcs.el ends here
