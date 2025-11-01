;; -*- lexical-binding: t; -*- 
(os/after eat
	  (global-set-key (kbd "C-c u") #'eat)
	  (global-set-key (kbd "C-c T") #'eat-other-window))
(gbind-multiple
 ("C-+" . text-scale-increase)
 ("C--" . text-scale-decrease))

(provide 'keybindings)
