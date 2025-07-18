;;; organizer.el --- An extension to org-mode functionality -*- lexical-binding: t -*-

;; Author: Oscar (Mester)
;; Version: 1.2.4
;; Package-Requires: ((emacs "29.1"))
;; Homepage: https://codeberg.org/mester/Organizer
;; Keywords: organizer organization extensions

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

;; Begin of code

;;; Code:

(defvar-keymap organizer-opts
  :doc "Keyboard binds for organizer options"
  :name "Organizer"
  "f" '("Organizer files selector" . organizer-files-selector)
  "i" '("Organizer index" . organizer-index)
  "a" '("Organizer agenda" . organizer-agenda)
  "b" '("Organizer item" . organizer-item))

(keymap-global-set "C-x j" organizer-opts)

(require 'organizer-dashboard-mode)

(defgroup organizer nil
  "Organizer system for improve things in org for me."
  :group 'applications
  :version "1.2.4"
  :prefix "organizer-"
  :link '(url-link :tag "Website" "https://codeberg.org/mester/Organizer"))


(defcustom organizer-directory org-directory
  "The organizer directory by default is the org directory but that yoy can change if you need."
  :group 'organizer
  :type 'directory)

(defcustom organizer-index-file (expand-file-name "index.org" organizer-directory)
  "File that is used as the index of organizer."
  :group 'organizer
  :type 'file)

 ;; :initialize
 ;;  (lambda (sym val)
 ;;    (set-default
 ;;     sym
 ;;     (or val (expand-file-name "index.org" organizer-directory))))

(defcustom organizer-files  (list (cons "Agenda"    (car org-agenda-files))
				  (cons "Notas"     (expand-file-name "notes.org" organizer-directory))
				  (cons "Index"     organizer-index-file)
				  (cons "Proyectos" (expand-file-name "proyectos.org" organizer-directory)))
  "Interesting files that are good to manage with organizer."
  :group 'organizer
  :type '(alist :key-type string :value-type file))

(defun organizer-files-selector (&optional key)
  "Allow to select one file and access to it from the files of 'organizer-files'.
Allowing to access to them you can access in two ways:
1. Interactive way: Using completing read allow to select interactively the file
2.Parameter way: Using KEY you can give the file of organizer file system to access
Example:
  (organizer-files-selector 'Proyectos') this proyectos will be passed through string and allow to access to proyectos.org file"
  (interactive)
  (let* ((seleccion (or key
                        (completing-read "Seleccione a qué parte de Organizer quiere acceder: "
                                         (mapcar #'car organizer-files) nil t)))
         (valor (cdr (assoc seleccion organizer-files))))
    (if (string= valor organizer-index-file)
        (organizer-index))
    (find-file valor)))

(defun organizer-item (writed_object)
  "Creation of a checkbox item in a `Org` file with a custom text storaged in WRITED_OBJECT and show if the insert worked or not."
  (interactive
   "sInsert the text that you want to use with checkbox: ")
  (if (eq major-mode 'org-mode)
      (progn (insert (format "- [ ] %s" writed_object))
	     (message "Insercion finalizada"))
    (message "La insercion de checklist solo esta permitida en Org Mode")))

(defun organizer-index ()
  "Open the Organizer index and activate the dashboard mode."
  (interactive)
  (find-file organizer-index-file)
  (organizer-dashboard-mode))

(defun organizer-agenda ()
  "Acceso a la agenda."
  (interactive)
  (split-window)
  (other-window 1)
  (find-file (format "%s/agenda.org" organizer-directory)))


(defun organizer-version ()
  "Version de organizer."
  (interactive)
  (message "Version: %s organizer.org" (get 'organizer 'custom-version)))


(provide 'organizer)
;;; organizer.el ends here
