(require 'org-tempo)
      (use-package org-appear
      :hook
      (org-mode . org-appear-mode))

   (use-package org-superstar
   :demand t  
   :ensure t
   :config
  (add-hook 'org-mode-hook (lambda () (org-superstar-mode 1)))
  (setq org-ellipsis "▼")
  (setq org-superstar-headline-bullets-list '("◉" "●" "○" "◆" "●" "○" "◆"))
  (setq org-superstar-item-bullet-alist '((?+ . ?➤) (?- . ?✦))))
  ;; Modernise Org mode interface
;  (use-package org-modern
;    :hook
;    (org-mode . global-org-modern-mode)
;    :custom
;    (org-modern-keyword nil)
;    (org-modern-checkbox nil)
;    (org-modern-table nil))
      (use-package org-fragtog
      :after org
      :custom
      (org-startup-with-latex-preview t)
      :hook
      (org-mode . org-fragtog-mode)
      :custom
      (org-format-latex-options
       (plist-put org-format-latex-options :scale 2)
       (plist-put org-format-latex-options :foreground 'auto)
       (plist-put org-format-latex-options :background 'auto)))
      (use-package ox-epub
      :demand t)
    (use-package ox-reveal)
(provide 'org-utilities)
