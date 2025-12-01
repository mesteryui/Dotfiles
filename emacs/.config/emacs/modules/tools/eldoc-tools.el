;; -*- lexical-binding: t; -*- 

(use-package posframe
  :ensure t)

(use-package eldoc-mouse
  :ensure t
  :hook (prog-mode . eldoc-mouse-mode)
  :custom
  (eldoc-mouse-hover-delay 0.15))


(provide 'eldoc-tools)
;;; eldoc-tools.el ends here
