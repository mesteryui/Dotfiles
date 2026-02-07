(use-package dired 
  :ensure nil 
  :custom ((dired-recursive-copies 'always)
           (dired-recursive-deletes 'always)
           (delete-by-moving-to-trash t)
           (dired-dwim-target t))
  :hook ((dired-mode . dired-hide-details-mode)
	 (dired-mode . hl-line-mode))
  :config
  (when-let* ((cmd (cond ((equal system-type 'darwin) "open")
			 ((equal system-type 'gnu/linux) "xdg-open")
			 ((equal system-type 'windows-nt) "start"))))
    (setopt dired-guess-shell-alist-user
	    `(("\\.\\(?:docx\\|pdf\\|djvu\\|eps\\)\\'" ,cmd)
	      ("\\.\\(?:jpe?g\\|png\\|gif\\|xpm\\)\\'" ,cmd)
	      ("\\.\\(?:xcf\\)\\'" ,cmd)
	      ("\\.csv\\'" ,cmd)
	      ("\\.tex\\'" ,cmd)
	      ("\\.\\(?:mp4\\|mkv\\|avi\\|flv\\|rm\\|rmvb\\|ogv\\)\\(?:\\.part\\)?\\'" ,cmd)
	      ("\\.\\(?:mp3\\|flac\\)\\'" ,cmd)
	      ("\\.html?\\'" ,cmd)
	      ("\\.md\\'" ,cmd))))
  (put 'dired-find-alternate-file 'disabled nil))

(use-package dired-x
  :ensure nil
  :hook (dired-mode . dired-omit-mode)
  :config
  ;; Make dired-omit-mode hide all "dotfiles"
  (setq dired-omit-verbose nil)
  (setq dired-omit-files
	(concat dired-omit-files "\\|^\\..*$")))
;; Additional syntax highlighting for dired
(use-package diredfl
  :hook
  (dired-mode . diredfl-mode))
;; highlight parent and directory preview as well
					;(dirvish-directory-view-mode . diredfl-mode)

(use-package dired-subtree
  :ensure t
  :after dired
  :bind
  ( :map dired-mode-map
    ("<tab>" . dired-subtree-toggle)
    ("TAB" . dired-subtree-toggle)
    ("<backtab>" . dired-subtree-remove)
    ("S-TAB" . dired-subtree-remove))
  :config
  (setq dired-subtree-use-backgrounds nil))

(use-package dired-preview
  :ensure t
  :hook (dired-mode . dired-preview-mode)
  :config
  (setq dired-preview-delay 0.7
	dired-preview-max-size (expt 2 20)
	dired-preview-ignored-extensions-regexp
        (concat "\\."
                "\\(gz\\|"
                "zst\\|"
                "tar\\|"
                "xz\\|"
                "rar\\|"
                "zip\\|"
                "iso\\|"
                "epub"
                "\\)")))

(use-package trashed
  :ensure t
  :commands (trashed)
  :config
  (setq trashed-action-confirmer 'y-or-n-p)
  (setq trashed-use-header-line t)
  (setq trashed-sort-key '("Date deleted" . t))
  (setq trashed-date-format "%Y-%m-%d %H:%M:%S"))

;; -*- lexical-binding: t; -*- 
(use-package dired-sidebar
  :ensure t
  :defer t
  :commands (dired-sidebar-toggle-sidebar)
  :init
  (setopt dired-sidebar-theme 'nerd)
  (setopt dired-sidebar-use-term-integration t)
  (setopt dired-sidebar-use-custom-font t))
(use-package dired-git
  :ensure t)
;;(global-set-key (kbd "C-c s") #'dirvish-side)
(provide 'dired)
