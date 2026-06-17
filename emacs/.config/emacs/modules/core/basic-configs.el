;;; -*- lexical-binding: t -*-
(setopt user-full-name "Oscar")

;; UI Defaults
(setopt inhibit-startup-message t
        use-short-answers t
        blink-matching-parent t)
(setq scroll-margin 8
      scroll-step 1
      scroll-conservatively 10000
      scroll-preserve-screen-position 1)
(electric-pair-mode)
(setopt display-time-24hr-format t
        display-time-format "%H:%M"
        frame-resize-pixelwise t
        frame-inhibit-implied-resize t)

;; Encoding
(set-default-coding-systems 'utf-8)
(prefer-coding-system 'utf-8)

;; Editing Behavior
(setopt enable-local-variables t
        vc-follow-symlinks t)

;; Files and Backups
(setopt load-prefer-newer t
        auto-save-default nil
        make-backup-files nil)

;; Calendar Configuration
(setopt calendar-week-start-day 1)
(setopt calendar-date-style 'iso)


(provide 'basic-configs)
