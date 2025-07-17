;; -*- lexical-binding: t; -*-

(defun os-window-delete-popup-frame (&rest _)
  "Kill selected selected frame if it has parameter `prot-window-popup-frame'.
Use this function via a hook."
  (when (frame-parameter nil 'os-window-popup-frame)
    (delete-frame)))
(defmacro functioner-create-window (command)
"Crear una funcion que ejecute un comando COMMAND."
 `(defun ,(intern (format "open-new-frame-%s" (symbol-name command))) ()
    ,(format "Run %s command in a new temporal frame using a hidden frame" (symbol-name command))
    (interactive)
    (let ((newer (make-frame '((os-window-popup-frame . t) (undecorated . t)))))
         (select-frame newer)
         (switch-to-buffer " os-window-hidden-buff")
         (condition-case nil
         (call-interactively ',command)
         ((quit error user-error)
           (delete-frame))))))
(declare-function org-capture "org-capture" (&optional goto keys))
(defvar org-capture-after-finalize-hook)

;;;###autoload (autoload 'os-window-popup-org-capture "os-window")
(functioner-create-window org-capture)

(add-hook 'org-capture-after-finalize-hook #'os-window-delete-popup-frame)

(defmacro os/add-to-list (list &rest elements)
`(progn ,@(seq-map (lambda (e) `(add-to-list ',list ,e)) elements)))

(defmacro os/after (package &rest body)
  "Ejecuta BODY tras cargar PACKAGE o los paquetes de la lista PACKAGE.
Si el paquete ya está cargado, se ejecuta inmediatamente.Si no, se espera a que se cargue."
  (let ((packages (if (listp package) package (list package))))
    `(progn
       ,@(seq-map (lambda (p)
                    `(if (featurep ',p)
                         (progn ,@body)
                       (with-eval-after-load ',p
                         ,@body)))
                  packages))))

(defmacro when-system (system &rest body)
"Ejecuta BODY solo si estamos en SYSTEM (gnu/linux, darwin, windows-nt)."
`(when (eq system-type ',system)
,@body))

(defmacro gbind (key func)
"Asigna atajos de teclado globales de forma más sencilla usando kbd:
KEY: Es el conjunto de teclas FUNC: Es la funcion que queremos asignar al atajo"
`(global-set-key (kbd ,key) ',func))

(defmacro unbind (key)
"Unbind the global KEY sequence."
`(global-unset-key (kbd ,key)))

(defmacro add-hooks (hook &rest funcs)
  "Añadir varias funciones a un hook.
Es decir si tengo 'org-mode-hook' puedo añadir varias funciones
siendo HOOK el hook que quiero añadir
y FUNCS las funciones a añadir"
  `(progn ,@(seq-map
	     (lambda (f) `(add-hook ',hook ,f))
	     funcs)))

(provide 'macros)
