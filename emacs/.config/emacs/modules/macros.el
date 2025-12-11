;; -*- lexical-binding: t; -*-

(defmacro os/add-to-list (list &rest elements)
  "Añadir multiples elementos al principio de una lista, siendo el ultimo en añadirse el primero al final ya que cada metodo se añade al principio"
  `(progn ,@(seq-map (lambda (e) `(add-to-list ',list ,e)) elements)))

(defmacro os/after (package &rest body)
  "Ejecuta BODY tras cargar PACKAGE o los paquetes de la lista PACKAGE.
Si el paquete ya está cargado, se ejecuta inmediatamente.Si no, se espera a que se cargue.
:if permite usar una sentencia condicional haciendo que la carga dependa de una condicion dada."
  (let* ((condt (cl-getf body :if))
	 (body (let ((b (copy-sequence body)))
		 (cl-remf b :if)
		 b)))
    (if condt
	`(when ,condt
           (if (featurep ',package)
	       (progn ,@body)
             (with-eval-after-load ',package
               (progn ,@body))))
      `(if (featurep ',package)
           (progn ,@body)
         (with-eval-after-load ',package
           (progn ,@body))))))

(defmacro when-system (sys &rest body)
  "Ejecuta BODY solo si estamos en SYSTEM (gnu/linux, darwin, windows-nt)."
  `(when (eq system-type ',sys)
     ,@body))

(defmacro gbind (key func)
  "Asigna atajos de teclado globales de forma más sencilla usando kbd:
KEY: Es el conjunto de teclas FUNC: Es la funcion que queremos asignar al atajo"
  `(global-set-key (kbd ,key) #',func))

(defmacro gbind-multiple (&rest binds)
  "Bind globally multiple BINDS, between keys and functions"
  `(progn
     ,@(mapcar (lambda (bind) `(global-set-key (kbd ,(car bind)) #',(cdr bind))) binds)))

(defmacro unbind (key)
  "Unbind the global KEY sequence."
  `(global-unset-key (kbd ,key)))

(defmacro add-hooks (hook &rest funcs)
  "Añadir varias funciones a un hook.
Es decir si tengo 'org-mode-hook' puedo añadir varias funciones
siendo HOOK el hook que quiero añadir
y FUNCS las funciones a añadir"
  `(progn ,@(seq-map
	     (lambda (f) `(add-hook ',hook #',f))
	     funcs)))

(provide 'macros)
;; End of macros
