;;; macros.el --- Custom macros for configuration -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: lisp, convenience

;;; Commentary:
;; This file contains custom macros used throughout the configuration
;; to simplify repetitive tasks like keybinding and list manipulation.

;;; Code:

(require 'cl-lib)
(require 'seq)

(defmacro os/add-to-list (list &rest elements)
  "Add multiple ELEMENTS to the beginning of LIST.
LIST is the symbol of the list variable.
ELEMENTS are the values to add.
The last element in ELEMENTS becomes the first in LIST (LIFO order of insertion)."
  `(progn ,@(seq-map (lambda (e) `(add-to-list ',list ,e)) elements)))

(defmacro os/after (package &rest body)
  "Execute BODY after loading PACKAGE or list of PACKAGES.
If PACKAGE is already loaded, execute BODY immediately.
If :if keyword is present, the loading depends on the condition.

Usage:
  (os/after org (setq ...))
  (os/after (org magit) (setq ...))
  (os/after org :if (display-graphic-p) (setq ...))"
  (let* ((condt (cl-getf body :if))
         (body (let ((b (copy-sequence body)))
                 (cl-remf b :if)
                 b)))
    (if condt
        `(when ,condt
           (if (featurep ',package)
               (progn ,@body)
             (with-eval-after-load ',package
               (progn ,@body))))
      `(if (featurep ',package)
           (progn ,@body)
         (with-eval-after-load ',package
           (progn ,@body))))))

(defmacro when-system (sys &rest body)
  "Execute BODY only if `system-type' is equal to SYS.
SYS should be a symbol like 'gnu/linux, 'darwin, or 'windows-nt."
  `(when (eq system-type ',sys)
     ,@body))

(defmacro gbind (key func)
  "Bind KEY to FUNC globally.
KEY is a string description of the key sequence (passed to `kbd`).
FUNC is the interactive function to call."
  `(global-set-key (kbd ,key) #',func))

(defmacro gbind-multiple (&rest binds)
  "Bind multiple global keys.
BINDS is a list of cons cells or lists where the car is the key
and the cdr is the function.

Usage:
  (gbind-multiple
   ("C-c a" . func-a)
   ("C-c b" . func-b))"
  `(progn
     ,@(mapcar (lambda (bind) `(global-set-key (kbd ,(car bind)) #',(cdr bind))) binds)))

(defmacro unbind (key)
  "Unbind the global KEY sequence.
KEY is a string description of the key sequence."
  `(global-unset-key (kbd ,key)))

(defmacro add-hooks (hook &rest funcs)
  "Add multiple FUNCS to a single HOOK.
HOOK is the hook variable symbol.
FUNCS are the functions to add to the hook."
  `(progn ,@(seq-map
             (lambda (f) `(add-hook ',hook #',f))
             funcs)))

(provide 'macros)
;;; macros.el ends here
