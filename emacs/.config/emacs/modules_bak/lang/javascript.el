;; -*- lexical-binding: t; -*-
(use-package js
    :ensure nil
    :custom
    (js-indent-level 2)
    :config
    (unbind-key "M-." js-base-mode-map))

(with-eval-after-load 'apheleia
  (setf (alist-get 'prettier apheleia-formatters)
        '("prettier" "--stdin-filepath" filepath))
  (setf (alist-get 'js-mode apheleia-mode-alist) 'prettier)
  (setf (alist-get 'json-mode apheleia-mode-alist) 'prettier)
  (setf (alist-get 'css-mode apheleia-mode-alist) 'prettier)
  (setf (alist-get 'html-mode apheleia-mode-alist) 'prettier))

(provide 'javascript)
