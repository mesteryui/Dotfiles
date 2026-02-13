;;; functions.el --- Custom utility functions -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: lisp, tools

;;; Commentary:
;; This file contains general utility functions used in the configuration
;; and for interactive use.

;;; Code:

(require 'macros)

(defun create-uv-project (archivo)
  "Create a custom 'uv' project at ARCHIVO directory and activate it.
Prompts for the project folder."
  (interactive "GIntroduzca la carpeta del proyecto: ")
  (let ((dir (file-name-as-directory archivo))) ; asegura que termine con /
    (unless (file-directory-p dir)
      (make-directory dir t)
      (message "Carpeta creada: %s" dir))
    (activate-project dir)))

(defun activate-project (dir)
  "Activate a 'uv' project in DIR.
Checks if `uv-init-cmd' is defined before calling it."
  (let ((default-directory dir))
    (when (fboundp 'uv-init-cmd)
      (uv-init-cmd dir))))

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

(defun append-to-gitignore (file)
  "Add FILE to the .gitignore of the current VC root."
  (interactive "fSelect a file to append in the gitignore: ")
  (with-current-buffer (find-file-noselect (expand-file-name ".gitignore" (vc-root-dir)))
    (end-of-buffer)
    (insert (format "\n%s" file))
    (save-buffer)))

(defun get-local-language ()
  "Retrieve the language definition from the Org buffer's header.
Looks for '#+LANGUAGE:'."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward
           "^#\\+LANGUAGE:[ \t]*\\(.*\\)$" nil t)
      (let ((lang (match-string-no-properties 1)))
        (cond
         ((equal lang "es") "es_ES")
         ((equal lang "en") "en_US")
         (t lang))))))

(defun dynamic-language-change ()
  "Change the dictionary based on the local Org language setting.
Uses `get-local-language' to determine the language."
  (when-let* ((lang (get-local-language)))
    (jinx-languages lang)))

(defun get-local-macro-definition (macro-name)
  "Retrieve the definition of a local Org mode MACRO-NAME."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (concat "^#\\+MACRO: " macro-name " \\(.*\\)") nil t)
      (match-string 1))))

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

(defun dictionary-switcher ()
  "Interactively switch between Spanish, English, and Esperanto dictionaries.
Only offers dictionaries different from the current one."
  (interactive)
  (let* ((dic ispell-current-dictionary)
         (change
          (completing-read "Seleccione el diccionario a usar: " mest-languages nil t))
         (result (cdr (assoc change mest-languages))))
    (unless (string= dic result)
      (ispell-change-dictionary result)
      (message "Diccionario cambiado desde %s a %s" dic change))))



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

(defun mester/kill-child-frames ()
  "Close all visible child-frames (pop-ups).
Useful for getting rid of stuck tooltips or completion frames."
  (interactive)
  (let ((killed-count 0))
    (dolist (frame (frame-list))
      (when (frame-parameter frame 'parent-frame)
        (delete-frame frame)
        (setq killed-count (1+ killed-count))))
    (if (> killed-count 0)
        (message "Cerrados %d pop-ups." killed-count)
      (message "No se encontraron pop-ups activos."))))

(gbind "C-x <deletechar>" mester/kill-child-frames)

(provide 'functions)
;;; functions.el ends here
