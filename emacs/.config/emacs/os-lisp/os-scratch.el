;;; os-scratch.el --- Extension for scratch mode -*- lexical-binding: t -*-

;; Author: Oscar
;; Version: 1.0
;; Package-Requires: ((emacs "29.1"))
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

;; Custom scratch based on prot scratch

;;; Code:

(defgroup os-scratch nil
  "Managing custom scratch."
  :group 'convenience)

(defvar os-scratch-messages `((org-mode . ,(format "#+title: Org Temporal buffer\n#+author: %s\n#+description: %s" user-full-name (string-trim (shell-command-to-string "date +%Y/%m/%d"))))
			      (emacs-lisp-mode . ";; Temporal buffer in Emacs Lisp Mode")
			      (bash-ts-mode . "#!/usr/bin/bash")
			      (gfm-mode . "# Try of a Markdown Github Readme"))
  "Messages for 'os-scratch'.")

(defun os-scratch--scratch-list-modes ()
  "List known major modes."
  (let (symbols)
    (mapatoms
     (lambda (symbol)
       (when (and (functionp symbol)
                  (or (provided-mode-derived-p symbol 'text-mode)
                      (provided-mode-derived-p symbol 'prog-mode)))
         (push symbol symbols))))
    symbols))

(defun os-scratch ()
  "Os scratch main function."
  (interactive)
  (let* ((mode (intern (completing-read "Select a mode: " (os-scratch--scratch-list-modes)))))
    (os-scratch-create-buffer mode)))

(defun os-scratch-buffer-list ()
  "Return a list of 'scratch:' buffers."
  (seq-filter (lambda (buf)
                (string-match "scratch:" (buffer-name buf)))
              (buffer-list)))

(defun os-scratch-select-buffer ()
  "Select a scratch buffer with 'os-scratch' format."
  (let* ((buffers (seq-map #'buffer-name (os-scratch-buffer-list)))
	 (buff (completing-read "Select a scratch: " buffers)))
    buff))

(defun os-scratch-pop-to-buffer (&optional buf)
  "Pop to a scratch buffer created by 'os-scratch' yo can use BUF to give a buffer."  
  (let* ((buff (or buf (os-scratch-select-buffer))))
    (pop-to-buffer buff)))

(defun os-scratch-buffer-p (buf)
  "Return non-nil if BUF is a scratch buffer."
  (string-match-p "scratch:" (buffer-name buf)))

(defun os-scratch-switch-to-buffer ()
  "Switch to a scratch buffer created by 'os-scratch'."
  (let* ((buff (os-scratch-select-buffer)))
    (switch-to-buffer buff)))

(defun os-scratch--buffer-name (mode)
  "Return the buffer of scratch buffer using the MODE."
  (format "*scratch:%s*" (string-replace "-mode" "" (symbol-name mode))))

(defun os-scratch--message-for-mode (mode)
  "Return the initial message for MODE."
  (or (cdr (assoc mode os-scratch-messages)) ""))

(defun os-scratch-create-buffer (mode)
  "Create a custom scratch buffer using a MODE."
  (let* ((buf (os-scratch--buffer-name mode)))
    (with-current-buffer (get-buffer-create buf)
      (funcall mode)
      (add-hook 'kill-buffer-hook (lambda () (when (not (one-window-p :no-minibuffer)) (delete-window))) nil t)
      (when (= (point-min) (point-max))
	(insert (os-scratch--message-for-mode mode))
	(if (string= (buffer-string) (os-scratch--message-for-mode mode))
	    (insert "\n\n")))
      (pop-to-buffer buf))))
(provide 'os-scratch)
;;; os-scratch.el ends here
