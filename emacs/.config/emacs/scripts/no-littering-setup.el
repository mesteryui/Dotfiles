;;; Package --- no-littering-setup
;;; Commentary:
;; Este paquete define variables que seran usadas por no-littering cuando el paquete sea instalado
;;; Code:
(defvar no-littering-etc-directory (expand-file-name "~/.cache/emacs/etc"))
(defvar no-littering-var-directory (expand-file-name "~/.cache/emacs/var"))
(when (boundp 'native-comp-eln-load-path)
  (startup-redirect-eln-cache (expand-file-name "eln-cache" no-littering-var-directory)))

;;; no-littering-setup ends here
(provide 'no-littering-setup)
