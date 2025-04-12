(require 'org-tempo)
             (use-package org-appear
             :hook
             (org-mode . org-appear-mode))

;; ;; Modern Org mode interface
    (use-package org-modern
      :hook
      (org-mode . org-modern-mode)
      :custom
      (org-modern-keyword t)
      (org-modern-checkbox t)
      (org-modern-table nil)
      (org-modern-star nil)
      (org-modern-todo nil))

(use-package org-superstar
            :demand t  
            :ensure t
	    :config
	    (setq org-superstar-headline-bullets-list '("◉" "●" "○" "✿" "󰓎" "" ""))
            (setq org-superstar-item-bullet-alist '((?+ . ?➤) (?- . ?✦)))
            (add-hook 'org-mode-hook (lambda () (org-superstar-mode 1))))
             (use-package ox-epub
             :demand t)
           (use-package ox-reveal)
       (provide 'org-utilities)
