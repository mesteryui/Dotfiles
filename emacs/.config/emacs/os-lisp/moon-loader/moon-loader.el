;;; moon-loader.el --- Loader of Emacs configuration packages -*- lexical-binding: t -*-

;; Author: Oscar
;; Version: 1.0
;; Package-Requires: ((emacs "26.1"))
;; Homepage: homepage
;; Keywords: keywords

;; This file is not part of GNU Emacs

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; commentary

;;; Code:

(eval-when-compile (require 'cl-lib))

(defgroup moon-loader nil
  "Moon loader configuration"
  :group 'applications)

(defcustom moon-loader-modules-dir (expand-file-name "modules/" user-emacs-directory)
  "Modules dir."
  :type 'directory
  :group 'moon-loader)


(defun moon-loader-add-subdirs-to-load-path (parent-dir)
  "Añade PARENT-DIR y todos sus subdirectorios al load-path recursivamente."
  (when (file-directory-p parent-dir)
    (let ((default-directory parent-dir))
      (add-to-list 'load-path parent-dir)
      (when (fboundp 'normal-top-level-add-subdirs-to-load-path)
	(normal-top-level-add-subdirs-to-load-path)))))


(defmacro moon-loader-add-modules (&rest modules)
  "Add MODULES one after another."
  `(progn
     ,@(mapcar
	(lambda (m)
	  (if (listp m)
	      (cl-destructuring-bind (name &key after) m
		`(moon-loader-load-module ',name :after ',after))
	    `(moon-loader-load-module ',m)))
	modules)))

(defun moon-loader-create-module (dir name)
  "Create a void module"
  (interactive (let* ((base (file-name-as-directory (expand-file-name moon-loader-modules-dir)))
		      (selected-dir (read-directory-name "Directory: " base base nil nil))
		      (module-name (read-string "New module name: ")))
		 (if (string-prefix-p base (expand-file-name selected-dir))
		     (list selected-dir module-name)
		   (error "Error the directory must be in %s" base))))

  (let* ((file-name (if (string-suffix-p ".el" name) name (concat name ".el"))) (file-path (expand-file-name file-name dir)) (buff (get-buffer-create file-name)))
    (unless (file-directory-p dir)
      (make-directory dir t))
    (with-current-buffer buff
      (erase-buffer)
      (emacs-lisp-mode)
      (set-visited-file-name file-path)
      (insert ";;; -*- lexical-binding: t -*-\n\n\n")
      (insert (format "(provide '%s)" (file-name-base file-name)))
      (save-buffer)
      (display-buffer (current-buffer)))))

(cl-defun moon-loader-load-module (module &key after)
  "Load the specificied MODULE."
  (let ((load-func (lambda (m)
		     (with-demoted-errors "Error in module: %S"
		       (require m)))))
    (if (or (null after) (featurep after))
	(funcall load-func module)
      (with-eval-after-load after
	(funcall load-func module)))))

(unless (file-directory-p moon-loader-modules-dir)
  (make-directory moon-loader-modules-dir t))

(moon-loader-add-subdirs-to-load-path moon-loader-modules-dir)

(provide 'moon-loader)
;;; moon-loader.el ends here
