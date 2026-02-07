;;; reading.el --- Tools for Reading (PDFs, eBooks) -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: reading, documents

;;; Commentary:
;; Configuration for DocView, PDF Tools, and EPUB reading (Nov.el).

;;; Code:

(use-package doc-view
  :demand t
  :ensure nil
  :custom
  (doc-view-resolution 300)
  (doc-view-mupdf-use-svg t)
  (large-file-warning-threshold (* 50 (expt 2 20)))
  :config
  (add-hook 'doc-view-mode-hook 'pdf-tools-install)
  (setq-default pdf-view-use-scaling t
                pdf-view-use-imagemagick nil))

(use-package nov
  :ensure t
  :mode ("\.epub\'" . nov-mode))

(provide 'reading)
;;; reading.el ends here

