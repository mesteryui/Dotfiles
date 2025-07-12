(use-package js
    :ensure nil
    :custom
    (js-indent-level 2)
    :config
    (unbind-key "M-." js-base-mode-map))
(provide 'javascript)
