;;; -*- lexical-binding: t -*-

(use-package dashboard
  :ensure t
  :init
  (add-hook 'dashboard-mode-hook (lambda () (setq show-trailing-whitespace nil)))
  :hook 
  (elpaca-after-init-hook . dashboard-insert-startupify-lists)
  (elpaca-after-init-hook . dashboard-initialize)
  :custom
  (dashboard-set-navigator t)
  (initial-buffer-choice 'dashboard-open) ;; Para que el buffer que aparece por defecto sea el dashboard cosa util si tienes el cliente y abres varias instancias
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)
  (dashboard-icon-type 'nerd-icons)
  (dashboard-display-icons-p t)     ; display icons on both GUI and terminal
  (dashboard-vertically-center-content t)
  (dashboard-banner-logo-title (format "Bienvenido a Emacs %s, %s" emacs-version user-full-name))
  (dashboard-startup-banner "~/.config/emacs/images/kawaii-sm.png")
  (dashboard-items '((recents . 5)
		     (agenda . 5)
		     (bookmarks . 3)))
  (dashboard-item-names '(("Recent Files:" . "Archivos Recientes:")
			  ("Bookmarks:" . "Marcadores:")
			  ("Agenda for the coming week:" . "Agenda para la próxima semana:")))
  (dashboard-navigator-buttons
   `((
      (,(nerd-icons-mdicon "nf-md-cog" :height 1.1 :v-adjust 0.0) ;; Icono del menu
       "Settings" "Open Config file" ;; Texto en el dashboard y texto cuando pasas el cursor
       (lambda (&rest _) (os/open-config))) ;; Lambda para ejecutar lo que se necesita para acceder a eso
      (,(nerd-icons-flicon "nf-linux-hyprland" :height 1.1 :v-adjust 0.0)
       "WM Settings" "Hyprland settings"
       (lambda (&rest _) (find-file "~/.config/hypr/hyprland.conf")))
      (,(nerd-icons-mdicon "nf-md-notebook" :height 1.1 :v-adjust 0.0)
       "Index" "Index of my Org"
       (lambda (&rest _) (organizer-index))))))
  (dashboard-startupify-list
   '(dashboard-insert-banner ;; Banner
     dashboard-insert-newline ;; Insertando nueva linea
     dashboard-insert-banner-title ;; Insertando banner del titulo
     dashboard-insert-newline
     dashboard-insert-navigator
     dashboard-insert-items
     dashboard-insert-newline
     dashboard-insert-footer
     dashboard-insert-init-info)) ;; Insertando informacion de inicio
  :config
  (dashboard-modify-heading-icons '((recents   . "nf-oct-file")
				    (projects  . "nf-oct-rocket")
				    (bookmarks . "nf-oct-bookmark")
				    (agenda    . "nf-oct-calendar")
				    (registers . "nf-oct-note")))
  (dashboard-setup-startup-hook))
(gbind "<f10>" open-dashboard)
(defun open-dashboard ()
  "Abre el buffer *dashboard* y salta al primer widget."
  (interactive)
  (delete-other-windows)
  ;; Refresca  dashboard buffer
  (if (get-buffer dashboard-buffer-name)
      (kill-buffer dashboard-buffer-name))
  (dashboard-insert-startupify-lists)
  (switch-to-buffer dashboard-buffer-name))


(provide 'main-dashboard)
