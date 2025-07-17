(setopt org-directory "~/org/")
(setopt diary-file (expand-file-name "diario.org" org-directory))
(setopt org-default-notes-file (expand-file-name "notes.org" org-directory))
(setopt org-agenda-files `( ,(expand-file-name "agenda.org" org-directory) ,(expand-file-name "proyectos.org" org-directory)))
(setopt org-archive-location "~/org/%s_archivo.org::datetree/")
(setq org-use-property-inheritance '("header-args"))

(use-package org
:ensure nil
:commands (org-mode org-version)
:hook ((org-mode . org-indent-mode)
(org-mode . os/org-headers-setters)
(org-mode . visual-line-mode)
(org-mode . dynamic-language-change))
:custom
;; Exportación
(org-export-with-drawers nil)
(org-export-with-todo-keywords nil)
(org-export-with-broken-links t)
(org-export-with-toc nil)
(org-export-with-smart-quotes t)
(org-export-date-timestamp-format "%d %B %Y")
;; Apariencia
(org-ellipsis "▼")
(org-startup-indented t)
(org-pretty-entities t)
(org-fontify-done-headline t)
(org-use-sub-superscripts "{}")
(org-hide-emphasis-markers t)
(org-hide-leading-stars t)
(org-startup-truncated t)
;; Imágenes
(org-startup-with-inline-images t)
(image-actual-width '(300))
;; Babel
(org-confirm-babel-evaluate nil)
;; Agenda
(org-agenda-skip-scheduled-if-done t)
;; Listas
(org-list-allow-alphabetical t)
;; Enlaces
(org-return-follows-link t)
:config
(require 'org-tempo))
(gbind "C-c c" org-capture)
(gbind "C-c a" org-agenda)
;; disable electric pairing for angle bracket

(add-hook 'org-mode-hook (lambda ()
  (setq-local electric-pair-inhibit-predicate
          `(lambda (c)
         (if (char-equal c ?<) t (,electric-pair-inhibit-predicate c))))))

(global-set-key [escape] 'keyboard-escape-quit)

(setopt calendar-month-name-array
	["Enero" "Febrero" "Marzo" "Abril" "Mayo" "Junio"
	 "Julio" "Agosto" "Septiembre" "Octubre" "Noviembre" "Diciembre"])

(setopt calendar-day-name-array
	["Domingo" "Lunes" "Martes" "Miércoles" "Jueves" "Viernes" "Sábado"])

(setopt org-todo-keywords
	'((sequence "TODO(t)" "NEXT(n)" "WAITING(w)" "PAUSED(P)" "|" "DONE(d)" "CANCELLED(c)")))
(setopt org-todo-keyword-faces
	'(("TODO" . "coral")
	  ("NEXT" . "cyan")
	  ("WAITING" . "yellow")
	  ("DONE" . "green")
	  ("PAUSED" . "IndianRed1")
	  ("CANCELLED" . "grey")))

(use-package org-wild-notifier
  :ensure t
  :after org
  :custom
  (org-wild-notifier-notification-title "Org Wild Reminder")
  (org-wild-notifier-alert-time (quote (1 10 30 1440 2880)))
  (alert-default-style 'libnotify)
  :config
  (org-wild-notifier-mode 1))

(electric-indent-mode 0)
(setq org-edit-src-content-indentation 0
org-src-preserve-indentation nil)

(setopt org-src-tab-acts-natively t
org-src-fontify-natively t)

(use-package org-appear
:hook
(org-mode . org-appear-mode))
;; ;; Modern Org mode interface
(use-package org-modern-indent
  :ensure (:host github :repo "jdtsmith/org-modern-indent")
  :config ; add late to hook
  (add-hook 'org-mode-hook #'org-modern-indent-mode 90))
(use-package org-modern
  :after org
  :hook (org-mode . org-modern-mode)
  (org-agenda-finalize . org-modern-agenda)
  :custom
  (org-modern-block-indent t)  ; to enable org-modern-indent when org-indent is active
  (org-modern-keyword t)
  (org-modern-table nil)
  (org-modern-star 'replace)
  (org-modern-replace-stars "◉○◈◇✿✳")
  (org-modern-checkbox
   '((?X . "✔")
     (?- . "┅")
     (?\s . "")))
  (org-modern-list '((?+ . "➤") (?- . "✦") (?* . "•")))
  (org-modern-todo-faces
   '(("TODO" :background "coral" :foreground "black")
     ("NEXT" :background "cyan" :foreground "black")
     ("PAUSED" :background "IndianRed1" :foreground "black")
     ("WAITING" :background "yellow" :foreground "black")
     ("DONE" :background "green" :foreground "white")
     ("CANCELLED" :background "gray" :foreground "white")))
  (org-modern-label-border 1)
)
(add-hook 'after-make-frame-functions
          (lambda (frame)
            (with-selected-frame frame
              (os/after org-modern
			(set-face-attribute 'org-modern-symbol nil :family "Aporetic Sans")))))
(use-package ox-epub
:demand t)
(use-package ox-reveal)
(use-package htmlize
:ensure t)

(setq org-capture-templates
      `(("t" "Tarea" entry
	 (file+headline "~/org/agenda.org" "Tareas")
	 "* TODO %?\n %i\n  %a")
	("n" "Nota" entry
	 (file+headline "~/org/notes.org" "Notas")
	 "* %? :nota:\n %i\n %a")
	("e" "Evento" entry
	 (file+headline "~/org/agenda.org" "Evento")
	 "* WAITING %?\n"
	 )
	("j" "Diario" entry
	 (file+datetree "~/org/diario.org")
	 "* Titulo de Entrada: %?\n")
	("p" "Project" entry
	 (file+headline "~/org/proyectos.org" "Proyectos")
	 "*  %?\n")))

(org-babel-do-load-languages
 'org-babel-load-languages
 '((emacs-lisp . t)
   (scheme . t)
   (python . t)
   (shell . t)))
(os/after org-contrib
	  (org-babel-do-load-languages 'org-babel-load-languages 
				       '((ledger . t))))

(use-package org-auto-tangle
:defer t
:hook (org-mode . org-auto-tangle-mode))

(use-package toc-org
:demand t
:commands toc-org-enable
:init (add-hook 'org-mode-hook 'toc-org-enable))

(use-package org-crypt
  :ensure nil
  :after org
  :custom
  (org-tags-exclude-from-inheritance (quote ("crypt")))
  (org-crypt-key "oscarodriguez56@gmail.com"))

(use-package org-contrib
:after org)

(provide 'org-config)
