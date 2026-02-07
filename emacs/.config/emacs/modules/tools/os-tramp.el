;;; -*- lexical-binding: t -*-

(use-package tramp
  :ensure t
  :custom
  (remote-file-name-inhibit-locks t)
  (tramp-use-scp-direct-remote-copying t)
  (tramp-copy-size-limit (* 1024 1024))
  (tramp-verbose 2)
  (tramp-persistency-file-name
   (no-littering-expand-var-file-name "tramp/history.el"))
  :config
  (connection-local-set-profile-variables
   'remote-direct-async-process
   '((tramp-direct-async-process . t)))
  (connection-local-set-profiles
   '(:application tramp :protocol "ssh")
   'remote-direct-async-process))
(use-package tramp-hlo
  :ensure (:host github :repo "jsadusk/tramp-hlo")
  :config
  (tramp-hlo-setup))


(provide 'os-tramp)
