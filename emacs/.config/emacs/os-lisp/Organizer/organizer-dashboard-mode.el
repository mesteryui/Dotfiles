;; Package --- It's a complement to organizer.el is licensed under the same license.;; -*- lexical-binding: t; -*-

;;; Comentary:
;; This is major to use the index of dashboard
;;; Code:
(defvar organizer-dashboard-mode-map
  (let* ((map (make-sparse-keymap)))
    (define-key map (kbd "a") #'organizer-agenda)
    (define-key map (kbd "s") #'organizer-files-selector)
    map)
  "Keymap for `organizer-dashboard-mode'.")


(define-derived-mode organizer-dashboard-mode org-mode "Organizer"
  "Major mode for Organizer dashboard."
  (run-hooks 'org-mode-hook)
  (setq buffer-read-only t)
  (remove-hook 'text-mode-hook 'flyspell-mode)
  (flyspell-mode -1))

(defun organizer-dashboard-mode-edit ()
  "Enable the edit the dashboard."
  (interactive)
  (org-mode)
  (read-only-mode 0)
  (flsypell-mode))


(provide 'organizer-dashboard-mode)
;;; organizer-dashboard-mode.el ends here
