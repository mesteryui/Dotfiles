(use-package vertico
  :ensure ;;(:host github :repo "minad/vertico.git")
  :hook
  (elpaca-after-init . vertico-mode)
  :custom
  (vertico-count 15)                    ; Número de candidatos a mostrar
  (vertico-resize t)
  (vertico-cycle t)
  (vertico-sort-function 'vertico-sort-history-alpha)
  :config
  (vertico-multiform-mode 1)
  (add-to-list 'vertico-multiform-categories '(embark-keybinding grid)))
;; Prompt indicator for `completing-read-multiple'.
(when (< emacs-major-version 31)
  (advice-add #'completing-read-multiple :filter-args
              (lambda (args)
                (cons (format "[CRM%s] %s"
                              (string-replace "[ \t]*" "" crm-separator)
                              (car args))
                      (cdr args)))))

(use-package emacs
  :ensure nil
  :custom
  ;; Enable context menu. `vertico-multiform-mode' adds a menu in the minibuffer
  ;; to switch display modes.
  (context-menu-mode t)
  ;; Support opening new minibuffers from inside existing minibuffers.
  (enable-recursive-minibuffers t)
  ;; Hide commands in M-x which do not work in the current mode.  Vertico
  ;; commands are hidden in normal buffers. This setting is useful beyond
  ;; Vertico.
  (read-extended-command-predicate #'command-completion-default-include-p)
  ;; Do not allow the cursor in the minibuffer prompt
  (minibuffer-prompt-properties
   '(read-only t cursor-intangible t face minibuffer-prompt)))

(use-package marginalia
  :commands (marginalia-mode marginalia-cycle)
  :custom
  (marginalia-annotators
   '(marginalia-annotators-heavy marginalia-annotators-lv))
  :init
  (marginalia-mode))
(provide 'minibuffer-improves)
