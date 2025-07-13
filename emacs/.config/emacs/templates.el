;; Local Variables:
;; flymake-mode: nil
;; End:

java-mode
(sout "System.out.println(" r> ");")
(syserr "System.err.println(" r> ");")
(souf "System.out.printf(" r> ");")
(method (r> (completing-read "Introduzca tipo funcion: " '("public" "private" "protected" "") nil t)) " " (r> "returnType") " " (r> "methodName") "() " "{" n q n "}")
(static-method (r> (completing-read "Introduzca tipo funcion: " '("public" "private" "protected" "") nil t)) " static " (r> "returnType") " " (r> "methodName") "() " "{" n q n "}")
(javadoc "/**" n "* " q n "*" n "*" n "**/")
(javadocClass "/**" n "* " n "* " "@author: " user-full-name n "* " "@version: " r> n "*" n "**/")
(trycatch "try {" n (r> "Codigo a comprobar") n "}" "catch (" (r> "Tipo de excecpcion") " " (r> "Nombre en el try catch") ") {" n q n "}")

org-mode
(title "#+title: " (r "Titulo por defecto"))
(normal-author "#+author: " user-full-name q)
(author "#+author: " (r "Introduzca nombre del autor") q)
(today (string-trim (shell-command-to-string "date +%Y/%m/%d")))

js-mode
(func "function " (r> "nombreFuncion") "(" r> ") {" n q n "}")
(apiQuest "fetch(" r> ").then(" r> ")")

html-mode mhtml-mode
(html5-document "<!DOCTYPE html>" n "<html lang=\"" (r> "en") "\">" n  "<head>" n "\t" "<meta charset=\"UTF-8\">" n
   "\t" "<meta name=\"viewport\"" "content=\"width=" (r> "device-width") ", initial-scale=" (r> "1.0\"") ">"  n "\t"
    "<title>" (r> "Introduzca titulo") "</title>" n "<head>" n "<body>" n q n "</body>")

(js-script "<script src=" (r> "\"script.js\"") " " r>"></script>")

(css-style "<link rel=\"stylesheet\" " "href=" (r> "\"style.css\"") ">")

(input:btn "<input type=\"button\"" " value=" (r> "\"valor\"") ">")

(input:text "<input type=\"text\"" " value=" (r> "\"valor\"") ">")

emacs-lisp-mode
(funct "(defun " (r> "nombre") "(" (r> "args") ")" n "\t" q ")")

