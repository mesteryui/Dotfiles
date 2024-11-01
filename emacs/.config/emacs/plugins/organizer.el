;;; Package --- orgnaizer
;;; Commentary:

;;; Code:
(defgroup organizer nil
    "Sistema de organizacion organzier."
     :version "1.0.0"
     :group 'applications)


(defvar organizer-directory "~/org")

(defun organizer-item (writed_object)
  "Creacion de un item checkbox, concepto almacenado en WRITED_OBJECT."
  (interactive
    "sIntroduce objeto al que se refiere el checkbox:")
    (insert (format "- [ ] %s" writed_object)))

(defun organizer-index ()
  "Indice para organizer."
  (interactive)
  (find-file (format "%s/index.org" organizer-directory))
  (read-only-mode))

(defun organizer-todo ()
  "Buscar tareas para hacer en agenda."
  (interactive)
  (find-file (format "%s/agenda.org" organizer-directory))
  (re-search-forward "TODO"))

(defun organizer-agenda ()
  "Acceso a la agenda."
  (interactive)
   (find-file (format "%s/agenda.org" organizer-directory)))


(defun organizer-version ()
  "Version de organizer."
  (interactive)
  (message "Version: 1.0.0 organizer.org"))

;;; organizer.el ends here.
(provide 'organizer)
