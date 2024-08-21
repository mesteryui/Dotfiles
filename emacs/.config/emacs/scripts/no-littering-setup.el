(defvar no-littering-etc-directory (expand-file-name "~/.cache/emacs/etc"))
(defvar no-littering-var-directory (expand-file-name "~/.cache/emacs/var"))
(when (boundp 'native-comp-eln-load-path)
  (startup-redirect-eln-cache (expand-file-name "eln-cache" no-littering-var-directory)))


(provide 'no-littering-setup)
