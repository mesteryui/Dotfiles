;; -*- lexical-binding: t; -*-

(use-package treemacs
  :defer t
  :init
  (global-set-key (kbd "C-c d") 'treemacs)
  (setq treemacs-hide-gitignored-files-mode t
	treemacs-project-follow-cleanup t
	treemacs-width 45
	treemacs-width-is-initially-locked nil
	delete-by-moving-to-trash t
	treemacs-collapse-dirs 3
	treemacs-display-in-side-window t
	treemacs-is-never-other-window t
	treemacs-indentation 2
	treemacs-indentation-string " "
	treemacs-filewatch-mode t
	treemacs-git-mode 'deferred
	treemacs-text-scale 1
	treemacs-move-files-by-mouse-dragging nil
	treemacs-move-forward-on-expand t
	treemacs-pulse-on-success t
	treemacs-file-event-delay 0
	treemacs-deferred-git-apply-delay 0
	treemacs-git-commit-diff-mode 1)
  (add-hook 'treemacs-mode-hook #'treemacs-project-follow-mode))

(use-package treemacs-nerd-icons
  :after nerd-icons
  :config
  (treemacs-load-theme "nerd-icons"))

(global-set-key (kbd "C-c f") 'treemacs)

(provide 'treemacs-conf)
