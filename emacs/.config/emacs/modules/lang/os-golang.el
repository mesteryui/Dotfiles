;;; os-golang.el --- Golang configuration -*- lexical-binding: t; -*-

(add-to-list 'auto-mode-alist '("\.go\'" . go-ts-mode))
(defun eglot-go-config ()
  (setq-local eglot-workspace-configuration
              '(:gopls (:analyses (:unusedparams t)
                                  :staticcheck t))))
(add-hook 'go-ts-mode-hook #'eglot-go-config)
(add-hook 'go-ts-mode-hook #'eglot-ensure)

(with-eval-after-load 'apheleia
  (setf (alist-get 'gofmt apheleia-formatters)
        '("gofmt"))
  (setf (alist-get 'go-mode apheleia-mode-alist) 'gofmt)
  (setf (alist-get 'go-ts-mode apheleia-mode-alist) 'gofmt))

(provide 'os-golang)
