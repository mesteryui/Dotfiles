;;; Package --- organizer
;;; Commentary:
;; Este es un sistema de organizacion que se complementa con el orgmode se pueden usar los directorios de org-directory que emacs setea lo recomendable o cualquier otro que decida para tener dos organizaciones independientes
;;; Code:
(defgroup organizer nil
    "Sistema de organizacion organzier.org."
     :version "1.0.0"
     :group 'applications)

(defvar organizer-directory "~/org")

(defun organizer-index ()
  "Indice para organizer.org."
  (interactive)
  (find-file (format "%s/index.org" organizer-directory))
  (read-only-mode))

(defun organizer-todo ()
  "Buscar tareas para hacer en agenda."
  (interactive)
  (find-file (format "%s/agenda.org" organizer-directory))
  (search-forward "TODO"))

(defun organizer-agenda ()
  "Acceso a la agenda."
  (interactive)
  (find-file (format "%s/agenda.org" organizer-directory)))

(defun organizer-version ()
  "Version de organizer.org."
  (interactive)
  (message "Version: 1.0.0 organizer.org"))

;;; organizer.el ends here
(provide 'organizer)
