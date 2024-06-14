#!/bin/bash

EMPID=$(pgrep emacs)
kill $EMPID
/usr/bin/emacs --daemon &
