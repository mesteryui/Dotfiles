;; -*- lexical-binding: t; -*-

(use-package qml-ts-mode
  :after eglot
  :ensure (:host "github" :repo "xhcoding/qml-ts-mode")
  :config
  (add-server qml-ts-mode  "qmlls")
  (add-hook 'qml-ts-mode-hook (lambda ()
				(setq-local electric-indent-chars '(?\n ?\( ?\) ?{ ?} ?\[ ?\] ?\; ?,))
				(eglot-ensure)))) 
(provide 'qml)
;;; qml.el ends here
