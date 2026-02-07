;;; -*- lexical-binding: t -*-

(use-package eldoc
  :ensure nil
  :hook (prog-mode . eldoc-mode)
  :custom
  (eldoc-documentation-strategy 'eldoc-documentation-compose-eagerly)
  (eldoc-message-function #'message)
  (eldoc-idle-delay 0.2))

(use-package posframe
  :ensure t)

(use-package eldoc-mouse
  :ensure t
  :hook (prog-mode . eldoc-mouse-mode)
  :custom
  (eldoc-mouse-hover-delay 0.15))



(provide 'os-eldoc)
