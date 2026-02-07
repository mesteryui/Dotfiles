;;; os-kdl.el --- KDL configuration -*- lexical-binding: t; -*-

(use-package kdl-ts-mode 
  :ensure (:host github :repo "dataphract/kdl-ts-mode")
  :init (add-to-list 'treesit-language-source-alist '(kdl "https://github.com/tree-sitter-grammars/tree-sitter-kdl"))
  (unless (treesit-language-available-p 'kdl)
    (treesit-install-language-grammar 'kdl)))

(provide 'os-kdl)
