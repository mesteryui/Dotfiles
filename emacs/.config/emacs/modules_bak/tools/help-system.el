;; -*- lexical-binding: t; -*-

;; Helpful is an alternative to the built-in Emacs help that provides much more
;; contextual information.
(use-package helpful
  :ensure t
  :commands (helpful-callable
             helpful-variable
             helpful-key
             helpful-command
             helpful-at-point
             helpful-function)
  :bind
  ([remap describe-command] . helpful-command)
  ([remap describe-function] . helpful-callable)
  ([remap describe-key] . helpful-key)
  ([remap describe-symbol] . helpful-symbol)
  ([remap describe-variable] . helpful-variable)
  :custom
  (helpful-max-buffers 7))

(use-package which-key
  :ensure nil
  :after (embark vertico)
  :config
  (which-key-mode)
  (setq prefix-help-command #'embark-prefix-help-command)
  :custom
  (which-key-idle-delay 0.2)
  (which-key-separator " → ") 
  (which-key-ellipsis "…"))

(provide 'help-system)
