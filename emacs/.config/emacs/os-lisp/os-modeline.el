;;; os-modeline.el --- A custom modeline -*- lexical-binding: t -*-

;; Author: Oscar
;; Version: 1.0
;; Package-Requires: ((emacs "30.1"))
;; Homepage: https://codeberg.org/mester
;; Keywords: extensions

;; This file is not part of GNU Emacs

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A custom basic modeline for Emacs

;;; Code:

;;(require 'nerd-icons)

(defgroup os-modeline nil
  "Custom modeline for me."
  :group 'mode-line)

(defcustom os-modeline-string-truncate-length 2
  "String length after which truncation should be done in small windows."
  :type 'natnum)

(defcustom os-modeline-bar-height 25
  "Height of modeline."
  :type 'integer
  :group 'os-modeline)

(defun os-modeline-calc-height ()
  "Devuelve la altura real en píxeles de la fuente usada en la mode-line."
  (let* ((face (if (facep 'mode-line) 'mode-line 'default))
         (height (face-attribute face :height nil t)))
    (cond
     ;; Si :height no está seteado o es inválido, usa altura estándar del frame
     ((or (null height) (not (numberp height)) (<= height 0))
      (frame-char-height))
     ;; Si height > 100, probablemente ya está en píxeles
     ((> height 100)
      height)
     ;; Si height es un factor (<100, por ejemplo 110 = 110%), convierte a píxeles
     (t
      (/ (* height (frame-char-height)) 100)))))

(defun os-modeline-obtain-height ()
  "Obtain the height to put in modeline settings."
  (max os-modeline-bar-height (os-modeline-calc-height)))

(set-face-attribute 'mode-line nil :height (os-modeline-obtain-height))

(defun os-modeline-treat-major-mode-names (name) ;; I use now mode-name that is more practical to do this
  "Traeat NAME of major-modes."
  (pcase name
    ("Emacs-Lisp" "Elisp")
    ("Typst--Markup" "Typst")
    (_ name)))

;; Faces

(defface os-modeline-red-background
  '((t :background "#3355bb" :foreground "#ffffff"))
  "Face with red background in modeline.")

(defface os-modeline-changes-not-saved
  '((t :inherit warning :height 1.0 :slant italic))
  "Face for not saved changes.")

(defface os-modeline-read-only-icon
  '((t :inherit warning :height 1.0))
  "Face for not saved changes icon.")


;; End of faces

;; FLymake
(declare-function flymake--severity "flymake" (type))
(declare-function flymake-diagnostic-type "flymake" (diag))

;; Based on `flymake--mode-line-counter'.
(defun os-modeline-flymake-counter (type)
  "Compute number of diagnostics in buffer with TYPE's severity.
TYPE is usually keyword `:error', `:warning' or `:note'."
  (let ((count 0))
    (dolist (d (flymake-diagnostics))
      (when (= (flymake--severity type)
               (flymake--severity (flymake-diagnostic-type d)))
        (cl-incf count)))
    (when (cl-plusp count)
      (number-to-string count))))

(defvar os-modeline-flymake-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line down-mouse-1] 'flymake-show-buffer-diagnostics)
    (define-key map [mode-line down-mouse-3] 'flymake-show-project-diagnostics)
    map)
  "Keymap to display on Flymake indicator.")


(defmacro os-modeline-flymake-type (type indicator &optional face)
  "Return function that handles Flymake TYPE with stylistic INDICATOR and FACE."
  `(defun ,(intern (format "os-modeline-flymake-%s" type)) ()
     (when-let* ((count (os-modeline-flymake-counter
                         ,(intern (format ":%s" type)))))
       (concat
        (propertize ,indicator 'face 'shadow)
        (propertize count
                    'face ',(or face type)
                    'mouse-face 'mode-line-highlight
                    ;; FIXME 2023-07-03: Clicking on the text with
                    ;; this buffer and a single warning present, the
                    ;; diagnostics take up the entire frame.  Why?
                    'local-map os-modeline-flymake-map
                    'help-echo "mouse-1: buffer diagnostics\nmouse-3: project diagnostics")))))

(os-modeline-flymake-type error " ") ;;☣
(os-modeline-flymake-type warning " ");;!
(os-modeline-flymake-type note "    " success) ;; ·


(defvar-local os-modeline-flymake
  '(:eval
    (when (and (bound-and-true-p flymake-mode)
               (mode-line-window-selected-p))
     (list
      '(:eval (os-modeline-flymake-error))
      '(:eval (os-modeline-flymake-warning))
      '(:eval (os-modeline-flymake-note)))))
  "Flymake status in the modeline.")

;; End of flymake

;; Keyboard macro indicator

(defvar-local os-modeline-kbd-macro
    '(:eval
      (when (and (mode-line-window-selected-p) defining-kbd-macro)
        (propertize " KMacro " 'face 'os-modeline-indicator-blue-bg)))
  "Mode line construct displaying `mode-line-defining-kbd-macro'.
Specific to the current window's mode line.")

;; End of Keyboard macro indicato

(defun os-modeline-window-narrow-p (&optional cols)
  "Return non-nil if the current window is narrow.
Optional argument COLS sets the column threshold.  Default is 80."
  (let ((limit (or cols 80)))
    (< (window-width) limit)))

(defvar os-modeline-current-time '(:eval (list (propertize "" 'face 'shadow) "  " (propertize (format-time-string "%a %d, %H:%M" (current-time)) 'help-echo (format-time-string "%a %d/%m/%y" (current-time)))))
  "Current time.")

(defun os-modeline--string-truncate-p (str)
  "Return non-nil if STR should be truncated."
  (cond
   ((or (not (stringp str))
        (string-empty-p str)
        (string-blank-p str))
    nil)
   ((and (os-modeline-window-narrow-p)
         (> (length str) os-modeline-string-truncate-length)
         (not (one-window-p :no-minibuffer))))))

(defun os-modeline-string-cut-end (str)
  "Return truncated STR, if appropriate, else return STR.
Cut off the end of STR by counting from its start up to
os-modeline-string-truncate-length'."
  (if (os-modeline--string-truncate-p str)
      (concat (substring str 0 os-modeline-string-truncate-length) "...")
    str))


;; Vc

(declare-function vc-git--symbolic-ref "vc-git" (file))

(defun os-modeline--vc-branch-name (file backend)
  "Return capitalized VC branch name for FILE with BACKEND."
  (when-let* ((rev (vc-working-revision file backend))
              (branch (or (vc-git--symbolic-ref file)
                          (substring rev 0 7))))
    (capitalize branch)))

;; NOTE 2023-07-27: This is a good idea, but it hardcodes Git, whereas
;; I want a generic VC method.  Granted, I only use Git but I still
;; want it to work as a VC extension.

;; (defun prot-modeline-diffstat (file)
;;   "Return shortened Git diff numstat for FILE."
;;   (when-let* ((output (shell-command-to-string (format "git diff --numstat %s" file)))
;;               (stats (split-string output "[\s\t]" :omit-nulls "[\s\f\t\n\r\v]+"))
;;               (added (nth 0 stats))
;;               (deleted (nth 1 stats)))
;;     (cond
;;      ((and (equal added "0") (equal deleted "0"))
;;       "")
;;      ((and (not (equal added "0")) (equal deleted "0"))
;;       (propertize (format "+%s" added) 'face 'shadow))
;;      ((and (equal added "0") (not (equal deleted "0")))
;;       (propertize (format "-%s" deleted) 'face 'shadow))
;;      (t
;;       (propertize (format "+%s -%s" added deleted) 'face 'shadow)))))

(declare-function vc-git-working-revision "vc-git" (file))

(defvar os-modeline-vc-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mode-line down-mouse-1] 'vc-diff)
    (define-key map [mode-line down-mouse-3] 'vc-root-diff)
    map)
  "Keymap to display on VC indicator.")

(defun os-modeline--vc-help-echo (file)
  "Return `help-echo' message for FILE tracked by VC."
  (format "Revision: %s\nmouse-1: `vc-diff'\nmouse-3: `vc-root-diff'"
          (vc-working-revision file)))


(defun os-modeline--vc-text (file branch &optional face)
  "Prepare text for Git controlled FILE, given BRANCH.
With optional FACE, use it to propertize the BRANCH."
  (concat
  ;; (propertize (char-to-string #xE0A0) 'face 'shadow)
   (propertize "" 'face 'shadow)
   " "
   (propertize branch
               'face face
               'mouse-face 'mode-line-highlight
               'help-echo (os-modeline--vc-help-echo file)
               'local-map os-modeline-vc-map)
   ;; " "
   ;; (prot-modeline-diffstat file)
   ))


(defun os-modeline--vc-details (file branch &optional face)
  "Return Git BRANCH details for FILE, truncating it if necessary.
The string is truncated if the width of the window is smaller
than `split-width-threshold'."
  (os-modeline-string-cut-end
   (os-modeline--vc-text file branch face)))
;; TODO Do that the bar works correctly
(defvar os-modeline--vc-faces
  '((added . vc-locally-added-state)
    (edited . vc-edited-state)
    (removed . vc-removed-state)
    (missing . vc-missing-state)
    (conflict . vc-conflict-state)
    (locked . vc-locked-state)
    (up-to-date . vc-up-to-date-state))
  "VC state faces.")

(defun os-modeline--vc-get-face (key)
  "Get face from KEY in `os-modeline--vc-faces'."
  (alist-get key os-modeline--vc-faces 'vc-up-to-date-state))

(defun os-modeline--vc-face (file backend)
  "Return VC state face for FILE with BACKEND."
  (when-let* ((key (vc-state file backend)))
    (os-modeline--vc-get-face key)))

(defvar-local os-modeline-vc-branch
    '(:eval
      (when-let* (((mode-line-window-selected-p))
                  (file (or buffer-file-name default-directory))
                  (backend (or (vc-backend file) 'Git))
                  ;; ((vc-git-registered file))
                  (branch (os-modeline--vc-branch-name file backend))
                  (face (os-modeline--vc-face file backend)))
        (os-modeline--vc-details file branch face)))
  "Mode line construct to return propertized VC branch.")

(defvar-local os-modeline-input-method '(:eval (when current-input-method-title (propertize (format " %s" current-input-method-title) 'mouse-face 'mode-line-highlight))))

(defun os-modeline--major-mode-name ()
  "Return the name of major mode applying what I need."
  (os-modeline-treat-major-mode-names (capitalize (string-replace "-mode" "" (symbol-name major-mode)))))
(defun os-modeline-buffer-name-help-echo ()
  "Return 'help-echo' value for 'prot-modeline-buffer-identification'."
  (concat
   (propertize (buffer-name) 'face 'mode-line-buffer-id)
   "\n"
   (propertize
    (or (buffer-file-name)
        (format "No underlying file.\nDirectory is: %s" default-directory))
    'face 'font-lock-doc-face)))

(defun os-modeline-major-mode-help-echo ()
  "Echo help for modeline-major-mode section."
  (let ((mode-name (string-replace "  " " " (string-replace "-" " " (capitalize (symbol-name major-mode))))))
    (concat mode-name
            "\n"
            (propertize (format "%s" major-mode)
                        'face 'font-lock-doc-face))))


(defun os-modeline-buffer-identification-face ()
  "Return appropriate face or face list for `os-modeline-buffer-identification'."
  (let ((file (buffer-file-name)))
    (cond
     ((and (mode-line-window-selected-p)
           file
           (buffer-modified-p))
      '(os-modeline-changes-not-saved mode-line-buffer-id))
     ((and file (buffer-modified-p))
      'os-modeline-changes-not-saved)
     ((mode-line-window-selected-p)
      'mode-line-buffer-id))))

(defun os-modeline-buffer-unsaved-icon ()
  "Obtain the icon of buffer type."
  (when (and (buffer-modified-p) (buffer-file-name))
	  (propertize " " 'face 'os-modeline-changes-not-saved)))

(defvar-local os-modeline-buffer-status
    '(:eval
      (when (file-remote-p default-directory)
        (propertize " @ "
                    'face 'error
                    'mouse-face 'mode-line-highlight)))
  "Mode line construct for showing remote file name.")

(defun os-modeline--buffer-name ()
  "Obtain the buffer name."
  (format " %s " (buffer-name)))

(defvar-local os-modeline-buffer-name '(:eval
					(when (mode-line-window-selected-p)
					  (list "  "
					        (nerd-icons-icon-for-buffer)
						(os-modeline-buffer-unsaved-icon)
						(propertize (os-modeline--buffer-name) 'face (os-modeline-buffer-identification-face) 'help-echo (os-modeline-buffer-name-help-echo))
						(when (and buffer-read-only (buffer-file-name))
						  (propertize "" 'face 'os-modeline-read-only-icon 'help-echo (propertize "Read Only Mode Activated" 'face 'font-lock-doc-face))))))
  "The buffer name.")


(defvar-local os-modeline-major-mode '(:eval
				       (list
					(propertize " λ " 'face 'shadow)
					(if (eq major-mode 'emacs-lisp-mode) mode-name (propertize  mode-name 'face 'bold 'help-echo (os-modeline-major-mode-help-echo)))))
  "Mode line major mode.")
;; (os-modeline--major-mode-name)
;; Eglot

(with-eval-after-load 'eglot
  (setq mode-line-misc-info
        (delete '(eglot--managed-mode (" [" eglot--mode-line-format "] ")) mode-line-misc-info)))

(defvar-local os-modeline-eglot
    `(:eval
      (when (and (featurep 'eglot) (mode-line-window-selected-p))
        '(eglot--managed-mode eglot--mode-line-format)))
  "Mode line construct displaying Eglot information.
Specific to the current window's mode line.")


;; End of eglot

;; Miscellaneous
(defvar-local os-modeline-misc-info
    '(:eval
      (when (mode-line-window-selected-p)
        mode-line-misc-info))
  "Mode line construct displaying 'mode-line-misc-info'.
Specific to the current window's mode line.")
;; End of Miscellaneous
(defun os-modeline--zoom (face)
  "Define the amount of zoom relative to normal text-scale you must pass the FACE you want the text of zoom uses."
  (and (boundp 'text-scale-mode-amount)
       (/= text-scale-mode-amount 0)
       (propertize
	(format
	 (if (> text-scale-mode-amount 0) " (%+d)" " (%-d)")
	 text-scale-mode-amount)
	'face face)))
(defvar os-modeline-zoom '(:eval (os-modeline--zoom 'shadow))
  "Os modeline zoom.")
(dolist (construct '(os-modeline-input-method
	             os-modeline-buffer-name
		     os-modeline-kbd-macro
		     os-modeline-buffer-status
		     os-modeline-major-mode
		     os-modeline-flymake
		     os-modeline-eglot
        	     os-modeline-vc-branch
		     os-modeline-misc-info
		     os-modeline-zoom
		     os-modeline-current-time))
  (put construct 'risky-local-variable t))


(provide 'os-modeline)
;;; os-modeline.el ends here

;; Local Variables:
;; jinx-languages: "en_US"
;; End:
