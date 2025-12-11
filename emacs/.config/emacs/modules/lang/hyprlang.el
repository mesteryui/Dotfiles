;; -*- lexical-binding: t; -*-

(use-package hyprlang-ts-mode
  :ensure t
  :if (eq system-type 'gnu/linux)
  :custom
  (hyprlang-ts-mode-indent-offset 4)
  :mode (("/hypr/.*config.*/" . hyprlang-ts-mode)
	 ("/hypr/config\\'" . hyprlang-ts-mode))
  :config
  (add-hook 'hyprlang-ts-mode #'eglot-ensure))

(add-server hyprlang-ts-mode "hyprls")

(provide 'hyprlang)
;;; hyprlang.el ends here
