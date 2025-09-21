;; Corfu: interfaz mínima y rápida de completado en buffer
(use-package corfu
  :ensure t
  :commands (corfu-mode global-corfu-mode)
  :bind (:map corfu-map ("<tab>" . corfu-complete))
  :custom
  (corfu-separator ?\s)  ; separador de palabra
  (corfu-cycle t)                 ; Allows cycling through candidates
  (corfu-auto t)                  ; Enable auto completion
  (corfu-auto-prefix 2)
  (corfu-auto-delay 0.1)
  (corfu-quit-no-match 'separator)
  (corfu-min-width 20)
  (corfu-quit-at-boundary nil)
  (corfu-preselect-first t)
  (corfu-quit-at-boundary 'separator)
  (corfu-popupinfo-delay '(1.25 . 0.5))
  (corfu-preview-current 'promt) ; insert previewed candidate
  (corfu-on-exact-match nil)
  :config 
  (os/after savehist
	    (add-to-list 'savehist-additional-variables 'corfu-history))
   :hook
    (elpaca-after-init . (lambda ()
                           (global-corfu-mode)
                           (corfu-history-mode)
                           (corfu-popupinfo-mode))))      ; activación global
;; (use-package corfu-terminal
;;    :after corfu
;;    :if (< emacs-major-version 31)
;;    :ensure (:type git :host codeberg :repo "akib/emacs-corfu-terminal.git")
;;    :config
;;    (unless (display-graphic-p)
;;       (corfu-terminal-mode)))
;; Cape: extensiones para completion-at-point
(use-package cape
  :ensure t
  :commands (cape-file cape-dabbrev cpae-elisp-block cape-dict cape-emoji)
  :bind ("C-c p" . cape-prefix-map)
  :init
  (add-hooks completion-at-point-functions cape-dabbrev cape-file cape-emoji cape-dict cape-keyword cape-elisp-block))
;; Atajos prácticos
;;(global-set-key (kbd "M-<tab>") #'completion-at-point) ; TAB para completado

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
(provide 'completion)
