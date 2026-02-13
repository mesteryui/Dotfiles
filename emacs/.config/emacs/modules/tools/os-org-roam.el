;;; -*- lexical-binding: t -*-

(use-package org-roam
  :ensure t
  :custom
  (org-roam-directory (file-truename "~/Documentos/Cerebro")) ; Tu carpeta de notas
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert))
  :config
  (org-roam-setup))

(use-package org-roam-ui
  :ensure t
  :after org-roam
  :config
  (setq org-roam-ui-sync-blink t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

(use-package simple-httpd
  :ensure t
  :after org-roam-ui)


(provide 'os-org-roam)
