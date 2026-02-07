;;; multimedia.el --- Multimedia Tools -*- lexical-binding: t; -*-

;; Author: Oscar
;; Keywords: multimedia, audio

;;; Commentary:
;; Tools for playing media, specifically radio via eradio.

;;; Code:

(require 'macros)

(use-package eradio
  :commands (eradio-play eradio-toggle)
  :custom
  (eradio-player '("mpv" "--no-video" "--no-terminal"))
  (eradio-channels '(("MGT Radio" . "https://stream.zeno.fm/koq3futfevouv")
                     ("Radio asiatica" . "https://stream.zeno.fm/vwvzwtapjrpvv")
                     ("Radio Libretics" . "https://stream-170.zeno.fm/a79lrhms108uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJhNzlscmhtczEwOHV2IiwiaG9zdCI6InN0cmVhbS0xNzAuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6IndQLS1ld3VYVGV5RjcxNUtmaXdMRkEiLCJpYXQiOjE3NDIxNTQ3NzIsImV4cCI6MTc0MjE1NDgzMn0.nR6YeM5BOcjVXbKfFaSLO6v_kLFFvdgnbGRtaO_UblY")
                     ("Cadena Dial" . "http://playerservices.streamtheworld.com/api/livestream-redirect/CADENADIAL.mp3")
                     ("Los 40 Principales" . "https://23553.live.streamtheworld.com:443/LOS40.mp3")))
  :config
  (gbind-multiple ("C-x r e" . eradio-toggle)
                  ("C-x r p" . eradio-play)))

(provide 'multimedia)
;;; multimedia.el ends here
