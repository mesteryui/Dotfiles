;;; -*- lexical-binding: t -*-

(use-package colorful-mode
  :ensure t
  :config
  ;; 1. ESTILO DE LA "BOLITA"
  (setq colorful-style 'prefix)          ; El color aparece antes del código
  (setq colorful-prefix-string "●")      ; El carácter de la bolita
  (setq colorful-prefix-padding 1)       ; Un espacio de separación para que no esté pegado
  
  ;; 2. ROBUSTEZ: Qué colores detectar
  ;; Esto asegura que detecte Hex, RGB, HSL y nombres de CSS
  (setq colorful-extra-color-keyword-functions '(colorful-add-hex-colors
                                                 colorful-add-color-names
                                                 colorful-add-rgb-colors
                                                 colorful-add-hsl-colors))

  ;; 3. SEGURIDAD: Liberar tus atajos C-c
  ;; Borramos el mapa de teclado del paquete para que no intercepte nada
  (setq colorful-mode-map (make-sparse-keymap))
  
  ;; Opcional: Si alguna vez quieres usar sus funciones, 
  ;; asígnalas a una tecla que no uses, como F8
  (define-key colorful-mode-map (kbd "<f5>") 'colorful-mode-map)
  (global-colorful-mode))

(provide 'os-colorful-mode)
