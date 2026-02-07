;; -*- lexical-binding: t; -*- 
(use-package embark
  :commands (embark-act embark-prefix-help-command embark-dwim embark-collect embark-bindings embark-export)
  :demand t
  :config
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none))))
  :bind
  (("C-c A" . embark-act)
   ("C-:" . embark-dwim)
   ("C-h B" . embark-bindings)))

(use-package embark-consult
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))
(provide 'embark-funcs)
