#!/usr/bin/env fish
set -l SWAYOSDPID (pgrep swayosd-server)
if test -n "$SWAYOSDPID"
    kill "$SWAYOSDPID"
end
swayosd-server &
