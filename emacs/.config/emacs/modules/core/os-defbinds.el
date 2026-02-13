;;; -*- lexical-binding: t -*-

(require 'os-macros)

(gbind-multiple
 ("C-+" . text-scale-increase)
 ("C--" . text-scale-decrease))


(provide 'os-defbinds)
