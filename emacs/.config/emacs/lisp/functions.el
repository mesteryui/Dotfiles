(defun create-uv-project (archivo)
  "Crear un proyecto de uv personalizado pasando la carpeta del proyecto como ARCHIVO y listo para empezar a editar."
  (interactive "GIntroduzca la carpeta del proyecto: ")
  (let ((dir (file-name-as-directory archivo))) ; asegura que termine con /
    (unless (file-directory-p dir)
      (make-directory dir t)
      (message "Carpeta creada: %s" dir))
    (activate-project dir)))

(defun activate-project (dir)
"Activar un proyecto de uv"
(let ((default-directory dir))
  (when (fboundp 'uv-init-cmd) ; solo si está definido
    (uv-init-cmd dir))))

(defun append-to-list (list-var elements)
"Append ELEMENTS to the end of LIST-VAR.
The return value is the new value of LIST-VAR."
(unless (consp elements)
  (error "ELEMENTS must be a list"))
(let ((list (symbol-value list-var)))
  (if list
      (setcdr (last list) elements)
    (set list-var elements)))
(symbol-value list-var))

(defun get-local-language ()
"Retrieve the definition the language org variable."
(save-excursion
  (goto-char (point-min))
  (when (re-search-forward
	 "^#\\+LANGUAGE:[ \t]*\\(.*\\)$" nil t)
    (let ((lang (match-string-no-properties 1)))
      (cond
       ((equal lang "es") "es_ES")
       ((equal lang "en") "en_US")
       (t lang))))))

(defun dynamic-language-change ()
"Define the dictionary used locally to apply the word correction,
using what the result of 'get-local-language' function if the result is nil doesn't happen any change in another case use the language returned by 'get-local-language'"
(when-let ((lang (get-local-language)))
  (setq ispell-local-dictionary lang)))

(defun get-local-macro-definition (macro-name)
"Retrieve the definition of a local Org mode macro."
(save-excursion
  (goto-char (point-min))
  (when (re-search-forward (concat "^#\\+MACRO: " macro-name " \\(.*\\)$") nil t)
    (match-string 1))))

(defun os/reload-config ()
  "Recargar configuracion Emacs."
  (interactive)
  (load-file (expand-file-name "init.el" user-emacs-directory))
  (sleep-for 0.90)
  (if (eq major-mode 'org-mode) (org-mode))
  (ignore (elpaca-process-queues)))
(gbind "C-c r" os/reload-config)

(defun os/open-config ()
"Abrir configuracion de Emacs."
(interactive)
(find-file (expand-file-name "README.org" user-emacs-directory)))
(gbind "C-x c" os/open-config)

(defun dictionary-switcher()
"Cambiar entre los diccionarios de Español, Esperanto e Ingles mediante un menu interactivo solo entre esos y solo a un diccionario distinto al seteado."
(interactive)
(let* ((dic ispell-current-dictionary)
       (change
	(completing-read "Seleccione el diccionario a usar: " os-languages nil t))
       (result (cdr (assoc change os-languages))))
  (unless (string= dic result)
    (ispell-change-dictionary result)
    (message "Diccionario cambiado desde %s a %s" dic change))))

(defun toggle-webserver ()
"Function to toggle a not much bigger webserver ChatGPT helping me to fix some things
This function allow to activate the webserver when you use but if there is a process of webserver the function kill it"
(interactive)
(let ((proc (get-process "webserver")))
(if (and proc (eq (process-status proc) 'run))  ;; Verifica si el proceso está corriendo
    (progn
       (delete-process "webserver")
       (message "Webserver stopped"))
       (make-process :name "webserver" :command '("npx" "browser-sync" "start" "--server" "--files" "**/*") :buffer "*webserver*" :filter (lambda (_proc output)
        (when (string-match "Local: http://localhost:3000" output) ;; Verificamos a traves de la salida si el servidor ya se ha desplegado
          (message " ✅ Webserver started")))))))

(defun org-temp-buffer (&optional template)
  "Acceder a un buffer temporal de orgmode."
  (interactive)
  (with-current-buffer (pop-to-buffer "*orgtemp*")
      (progn (insert (format "#+title: %s\n#+description:%s\n#+author: %s\n\n" (or template "Temporal Buffer")
			       (format-time-string "%Y-%m-%d") user-full-name))
	     (org-mode)
	     (goto-char (point-max)))))

(defun prot/keyboard-quit-dwim ()
  "Do-What-I-Mean behaviour for a general `keyboard-quit'.

The generic `keyboard-quit' does not do the expected thing when
the minibuffer is open.  Whereas we want it to close the
minibuffer, even without explicitly focusing it.

The DWIM behaviour of this command is as follows:

- When the region is active, disable it.
- When a minibuffer is open, but not focused, close the minibuffer.
- When the Completions buffer is selected, close it.
- In every other case use the regular `keyboard-quit'."
  (interactive)
  (cond
   ((region-active-p)
    (keyboard-quit))
   ((derived-mode-p 'completion-list-mode)
    (delete-completion-window))
   ((> (minibuffer-depth) 0)
    (abort-recursive-edit))
   (t
    (keyboard-quit))))

(define-key global-map (kbd "C-g") #'prot/keyboard-quit-dwim)

(provide 'functions)
