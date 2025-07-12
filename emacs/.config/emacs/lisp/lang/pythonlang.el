(use-package uv
  :ensure (uv :type git :host github :repo "johannes-mueller/uv.el")
  :init
  (add-to-list 'treesit-language-source-alist '(toml "https://github.com/tree-sitter-grammars/tree-sitter-toml"))
  (unless (treesit-language-available-p 'toml)
    (treesit-install-language-grammar 'toml)))
(use-package tomlparse
  :ensure (:type git :host github :repo "johannes-mueller/tomlparse.el"))
(provide 'pythonlang)
