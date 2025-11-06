;; ;;; settings.el --- General settings -*- lexical-binding: t -*-

;;; Commentary:

;; Some settings: Specific settings for emacs

;;; Code:

(electric-pair-mode 1)

;; auto update file from disk
(global-auto-revert-mode 1)

;; UTF-8 as defaul
(set-default-coding-systems 'utf-8)
(prefer-coding-system 'utf-8)

(use-package exec-path-from-shell
  :ensure t
  :init
  (exec-path-from-shell-initialize)
  :config 
  (exec-path-from-shell-copy-env "PASSWORD_STORE_DIR"))

(provide 'settings)
;;; settings.el ends here
