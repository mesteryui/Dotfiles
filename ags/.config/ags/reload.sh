#!/bin/bash

ags quit &>/dev/null

sleep 0.3

ags run & disown
