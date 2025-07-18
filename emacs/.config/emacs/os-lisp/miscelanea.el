(defun show-image (file)
  (let ((buf (get-buffer-create "*Visor de imagenes*")))
    (with-current-buffer buf
      (read-only-mode -1)
      (erase-buffer)
      (insert-image (create-image file))
      (image-mode)
      (read-only-mode 1)
      (pop-to-buffer buf))))

(defun show-remote-image (url)
  "From a url creates a temporal file that is used to see the image."
  (let ((tmp (make-temp-file "emacs-img-" nil)))
    (url-copy-file url tmp t)
    (show-image tmp)))


