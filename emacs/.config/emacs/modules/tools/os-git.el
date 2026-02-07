;;; -*- lexical-binding: t -*-

(use-package magit
  :after transient
  :bind
  ("C-x g" . magit-status))

(use-package magit-stats
  :ensure t)

(use-package git-gutter
  :defer 0.3
  :delight
  :init (global-git-gutter-mode))

(use-package git-timemachine
  :defer 1
  :delight)



(provide 'os-git)
