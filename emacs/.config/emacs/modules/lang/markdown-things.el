;;; -*- lexical-binding: t -*-

(use-package markdown-mode
  :commands (markdown-mode gfm-mode)
  :mode (("README\\.md\\'" . gfm-mode)
	 ("\\.md\\'" . gfm-mode)
	 ("\\.markdown\\'" . markdown-mode))
  :init (setq markdown-command "pandoc -f gfm -t html5 --mathjax --highlight-style=kate")
  :hook ((markdown-mode . visual-line-mode)
	 (gfm-mode . visual-line-mode))
  :custom
  (markdown-fontify-code-blocks-natively t)
  (markdown-enable-math t)
  (markdown-asymmetric-header t)
  (markdown-header-scaling t)
  (markdown-header-scaling-values '(1.8 1.5 1.3 1.1 1.0 1.0))
  (markdown-make-gfm-checkboxes-buttons t)
  (markdown-gfm-uppercase-checkbox t)
  ;; Built-in live preview settings
  (markdown-split-window-direction 'right)  ; Preview on right side
  )

(use-package markdown-preview-mode
  :ensure t
  :commands (markdown-preview-mode)
  :bind (:map markdown-mode-command-map
	      ("p" . markdown-preview-mode)))

(provide 'markdown-things)
