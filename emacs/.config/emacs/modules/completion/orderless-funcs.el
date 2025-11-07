;; -*- lexical-binding: t; -*- 
(use-package orderless
  :demand t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides
   '((file (styles basic partial-completion)))))
(provide 'orderless-funcs)
