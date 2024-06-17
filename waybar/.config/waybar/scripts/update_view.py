#!/usr/bin/python

from os import path, stat
from datetime import datetime as dt

upd = '/tmp/upd/updates'
upv = '/tmp/upd/versions'
upv_n = '/tmp/upd/versions.new'

percentage = 100 # don't move [10]
tooltip = open(upd, 'r').read().rstrip("\n")

with open(upv_n, 'r') as cn:
    new_c = sum(1 for _ in cn)

mod_tstamp_v = path.getmtime(upv)
mod_tstamp_n = path.getmtime(upv_n)
mod_datetime_v = dt.fromtimestamp(mod_tstamp_v).strftime("%H:%M %d %b")
mod_datetime_n = dt.fromtimestamp(mod_tstamp_n).strftime("%H:%M %d %b")

if stat(upv).st_size == 0:
    percentage = 0 # don't move [22]
    clss = "up-to-date"
else:
    if open(upv, 'r').read().rstrip("\n") != 'refreshing':
        percentage = 100
        clss = "updates" # don't move [27]
    else:
        percentage = 50
        clss = "refreshing"
        tooltip = "refreshing db..."

bttn = "<span color=\'#555555\'>On click: view updates\\nRight-click: refresh db</span>"

if percentage != 30 and percentage != 70:
    match clss:
        case 'refreshing':
            print(f'{{"class":"{clss}","percentage": {percentage},"tooltip": "{tooltip}"}}')
        case 'new-updates':
            print(f'{{"class":"{clss}","percentage": {percentage},"tooltip": "{new_c} '\
                  f'new update(s) found...","text":"<span color=\'#4CDD85\'>{new_c}</span>"}}')
        case _:
            print(f'{{"class":"{clss}","percentage": {percentage},"tooltip": "Total: '\
                  f'<span color=\'#1793D1\'>{tooltip}</span>  @{mod_datetime_v}\\nNew: '\
                  f'<span color=\'#4CDD85\'>{new_c}</span>  @{mod_datetime_n}\\n{bttn}",'\
                  f'"text":"<span color=\'#1793D1\'>{tooltip}</span>"}}')
else:
    clss = "offline"
    print(f'{{"class":"{clss}","percentage": {percentage},"tooltip": "{clss}"}}')

# Source code: "https://bbs.archlinux.org/viewtopic.php?id=279522"


