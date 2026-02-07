;;; os-qml.el --- QML configuration -*- lexical-binding: t; -*--

(use-package qml-ts-mode
  :after eglot
  :ensure (:host "github" :repo "xhcoding/qml-ts-mode")
  :config
  (add-server qml-ts-mode  "qmlls")
  (add-hook 'qml-ts-mode-hook (lambda () 
                                (setq-local electric-indent-chars '(?
 ?( ?) ?{ ?} ?[ ?] ?; ?,))
                                (eglot-ensure)))) 

(provide 'os-qml)
