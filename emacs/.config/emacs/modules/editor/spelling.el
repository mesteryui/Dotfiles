;; -*- lexical-binding: t; -*- 
(use-package flyspell
  :ensure nil
  :defer t
  :if (eq mester/spell-checker 'flyspell)
  :init
  :config
  (setopt ispell-silently-savep t
	  flyspell-case-fold-duplications t
	  flyspell-issue-message-flag nil
	  flyspell-default-dictionary "es_ES"
	  ispell-program-name "hunspell"
	  ispell-alternate-dictionary "/usr/share/dict/words") ;; Instalar paquete words en a
  :hook (text-mode . flyspell-mode)
  :bind(("M-<f7>" . flyspell-buffer)
	("<f7>" . flyspell-word)))

(use-package flyspell-correct
  :after (flyspell)
  :if (eq mester/spell-checker 'flyspell)
  :bind (("C-;" . flyspell-auto-correct-previous-word)
	 ("<f7>" . flyspell-correct-wrapper)))

(use-package jinx
  :ensure t
  :if (eq mester/spell-checker 'jinx)
  :hook (((text-mode prog-mode) . jinx-mode))
  :bind (("<f7>" . jinx-correct))
  :custom
  (jinx-delay 0.01))

(provide 'spelling)
