;;; os-corfu.el --- Corfu and Cape configuration -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: completion, convenience

;;; Commentary:
;; Configuration for Corfu (in-buffer completion) and Cape (completion at point extensions).

;;; Code:

(require 'os-macros)

;; Corfu: minimal and fast in-buffer completion interface
(use-package corfu
  :ensure t
  :after orderless
  :commands (corfu-mode global-corfu-mode)
  :bind (:map corfu-map ("<tab>" . corfu-complete))
  :custom
  (corfu-separator ?\s)           ; separator for filtering
  (corfu-cycle t)                 ; Allows cycling through candidates
  (corfu-auto t)                  ; Enable auto completion
  (corfu-scroll-margin 5)
  (corfu-auto-delay 0.2)
  (corfu-quit-no-match 'separator)
  (corfu-min-width 20)
  (corfu-quit-at-boundary nil)
  (corfu-auto-trigger ".")        ; Custom trigger characters
  ;;(corfu-preselect-first t)
  (completion-styles '(orderless basic)) ;; IDE-like fuzzy matching
  (corfu-popupinfo-delay '(1.25 . 0.5))
  (corfu-preview-current 'prompt)  ; insert previewed candidate
  (corfu-on-exact-match nil)
  :config 
  (corfu-history-mode t)          ; Remember completions
  (corfu-popupinfo-mode t)        ; Show documentation popup
  (os/after savehist
	    (add-to-list 'savehist-additional-variables 'corfu-history))
  :hook
  (elpaca-after-init . (lambda ()
                         (global-corfu-mode)
                         (corfu-history-mode)
                         (corfu-popupinfo-mode))))

;; Cape: Completion At Point Extensions
(use-package cape
  :ensure t
  :commands (cape-file cape-dabbrev cape-elisp-block cape-dict cape-emoji)
  :bind ("C-c p" . cape-prefix-map)
  :init
  (add-hooks completion-at-point-functions cape-dabbrev cape-file cape-emoji cape-dict cape-keyword cape-elisp-block))

(use-package emacs
  :ensure nil
  :custom
  ;; TAB cycle if there are only few candidates
  ;; (completion-cycle-threshold 3)

  ;; Enable indentation+completion using the TAB key.
  ;; `completion-at-point' is often bound to M-TAB.
  (tab-always-indent 'complete)
  ;; Emacs 30 and newer: Disable Ispell completion function.
  ;; Try `cape-dict' as an alternative.
  (text-mode-ispell-word-completion nil)

  ;; Hide commands in M-x which do not apply to the current mode.  Corfu
  ;; commands are hidden, since they are not used via M-x. This setting is
  ;; useful beyond Corfu.
  (read-extended-command-predicate #'command-completion-default-include-p))

(use-package completion-preview 
  :ensure nil
  :init
  (setq completion-preview-overlay-enable nil)
  (setq completion-preview-inline-enable t)
  (global-completion-preview-mode 1))

(use-package nerd-icons-corfu
  :after (corfu nerd-icons)
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

(provide 'os-corfu)
;;; os-corfu.el ends here
