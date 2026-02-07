;;; productivity.el --- Productivity Tools -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: productivity, org, calendar, passwords

;;; Commentary:
;; A suite of productivity tools including Organizer, Org-Social,
;; Password Store interface, and Calendar widgets.

;;; Code:

(require 'macros)

;; Organizer (Custom)
(use-package organizer
  :after org
  :load-path "os-lisp/Organizer/"
  :config
  (gbind "<f12>" organizer-index)
  (add-to-list 'organizer-files `("Libros" . ,(expand-file-name "Libros.org" org-directory)))
  (add-to-list 'organizer-files `("Finanzas" . ,(expand-file-name "Finanzas.org" org-directory))))

;; Org Social
(use-package org-social
  :ensure (:host github :repo "tanrax/org-social.el")
  :config
  (setq org-social-file "~/Escritorio/CosasSociales/social.org")
  (setq org-social-my-public-url "https://codeberg.org/mester/CosasSociales/raw/branch/main/social.org"))

;; Password Store
(use-package password-store
  :ensure t
  :bind ("C-c k" . password-store-copy)
  :config
  (setq password-store-time-before-clipboard-restore 30))

(use-package pass
  :ensure t
  :commands (pass))

;; Calendar (Calfw)
(use-package calfw
  :config
  (setopt cfw:org-overwrite-default-keybinding t))
(setopt cfw:display-calendar-holidays t)

(use-package calfw-org
  :after calfw
  :ensure t
  :config
  (setq cfw:org-overwrite-default-keybinding t)
  :bind ([f8] . calfw-org-open-calendar))

;; Timers
(use-package tmr
  :ensure t
  :bind
  ("C-c t" . tmr-prefix-map)
  :config
  (setq tmr-sound-file "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
        tmr-notification-urgency 'normal
        tmr-description-list 'tmr-description-history))

(provide 'productivity)
;;; productivity.el ends here
