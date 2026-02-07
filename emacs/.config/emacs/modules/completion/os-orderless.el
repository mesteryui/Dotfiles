;;; os-orderless.el --- Orderless configuration -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: completion

;;; Commentary:
;; Configuration for Orderless (completion style).

;;; Code:

(use-package orderless
  :demand t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides
   '((file (styles basic partial-completion)))))

(provide 'os-orderless)
;;; os-orderless.el ends here
