;;; common-tools.el --- Common Utilities and Tools -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: tools

;;; Commentary:
;; This file configures built-in Emacs tools like World Clock,
;; Shell interaction (Comint), and Compilation.

;;; Code:

;; World Clock
(use-package time
  :ensure nil
  :commands (world-clock)
  :config
  (setq display-time-world-list t)
  (setq zoneinfo-style-world-list
        '(("Europe/Athens" "Athens")
          ("Europe/Madrid" "Madrid")
          ("Asia/Tokyo" "Tokio")))
  (setq world-clock-list t)
  (setq world-clock-time-format "%z %R	%a %d %b (%Z)")
  (setq world-clock-buffer-name "*world-clock*")
  (setq world-clock-timer-enable t)
  (setq world-clock-timer-second 60))

;; Comint (Shell/REPL Interface)
(use-package comint
  :ensure nil
  :hook
  (comint-output-filter-functions . comint-osc-process-output)
  :config
  (setq ansi-color-for-comint-mode t)
  (setq comint-prompt-read-only t)
  (setq comint-buffer-maximum-size 9999)
  (setq comint-completion-autolist t)
  (setq comint-input-ignoredups t)
  (setq-default comint-scroll-to-bottom-on-input t)
  (setq-default comint-scroll-to-bottom-on-output nil)
  (setq-default comint-input-autoexpand 'input))

;; Compilation Interface
(use-package compile
  :ensure nil
  :hook
  (compilation-filter . ansi-color-compilation-filter)
  :config
  (setq ansi-color-for-comint-mode t))

(provide 'common-tools)
;;; common-tools.el ends here
