;; -*- lexical-binding: t; -*-


;;;; World clock (M-x world-clock)
(use-package time
  :ensure nil
  :commands (world-clock)
  :config
  (setq display-time-world-list t)
  (setq zoneinfo-style-world-list ; M-x shell RET timedatectl list-timezones
        '(("Europe/Athens" "Athens")
          ("Europe/Madrid" "Madrid")
          ("Asia/Tokyo" "Tokio")))

  ;; All of the following variables are for Emacs 28
  (setq world-clock-list t)
  (setq world-clock-time-format "%z %R	%a %d %b (%Z)")
  (setq world-clock-buffer-name "*world-clock*") ; Placement handled by `display-buffer-alist'
  (setq world-clock-timer-enable t)
  (setq world-clock-timer-second 60))

;;; Generic interface for shells or REPLs (comint)
(use-package comint
  :ensure nil
  ;; Support for OS-specific escape sequences such as what `ls
  ;; --hyperlink' uses.  I normally don't use those, but I am checking
  ;; this to see if there are any obvious advantages/disadvantages.
  :hook
  (comint-output-filter-functions . comint-osc-process-output)
  :config
  (setq ansi-color-for-comint-mode t) ; also see `ansi-color-for-compilation-mode'
  (setq comint-prompt-read-only t)
  (setq comint-buffer-maximum-size 9999)
  (setq comint-completion-autolist t)
  (setq comint-input-ignoredups t)
  (setq-default comint-scroll-to-bottom-on-input t)
  (setq-default comint-scroll-to-bottom-on-output nil)
  (setq-default comint-input-autoexpand 'input))
;;; Compilation interface (M-x compile)
(use-package compile
  :ensure nil
  :hook
  (compilation-filter . ansi-color-compilation-filter)
  :config
  (setq ansi-color-for-compilation-mode t)) ; also see `ansi-color-for-comint-mode'
(provide 'tools)
