;;; -*- lexical-binding: t -*-
(use-package doom-modeline
  :ensure t
  :after (nerd-icons)
  :hook (elpaca-after-init-hook . doom-modeline-mode)
  :config
  (setq doom-modeline-height 25)
  (setq doom-modeline-window-width-limit 90)
  (setq doom-modeline-project-detection 'auto)
  (setq doom-modeline-modal-modern-icon t))


(provide 'os-modeline)
