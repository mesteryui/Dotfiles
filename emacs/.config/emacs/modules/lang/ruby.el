;; -*- lexical-binding: t; -*-
(use-package ruby-mode :ensure nil)
(use-package ruby-ts-mode
  :ensure nil
  :mode "\\.rb\\'"
  :mode "Rakefile\\'"
  :mode "Gemfile\\'"
  :custom
  (ruby-indent-level 2)
  (ruby-indent-tabs-mode nil))
(provide 'ruby)
