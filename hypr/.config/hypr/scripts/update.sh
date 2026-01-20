#!/bin/bash

sudo -v || exit 1

yay -Syu

read -n "Actualizacion finalizada"
