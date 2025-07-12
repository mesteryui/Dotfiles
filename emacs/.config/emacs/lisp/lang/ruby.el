(use-package ruby-mode :ensure nil)
(use-package ruby-ts-mode
  :ensure nil
   :mode "\\.rb\\'"
   :mode "Rakefile\\'"
   :mode "Gemfile\\'")
(provide 'ruby)
