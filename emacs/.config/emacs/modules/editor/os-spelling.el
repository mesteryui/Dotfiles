;;; os-spelling.el --- Spelling configuration -*- lexical-binding: t; -*-

(use-package jinx
  :ensure t
  :hook (((text-mode prog-mode) . jinx-mode))
  :bind (("<f7>" . jinx-correct))
  :custom
  (jinx-delay 0.01))

(provide 'os-spelling)
