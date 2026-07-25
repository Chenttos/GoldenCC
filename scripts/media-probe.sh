#!/bin/zsh
# Open Control Center, run the CCAster media probe, print the log.
DIR="${0:a:h}"
"$DIR/mcp.sh" swipe_screen '{"x1":350,"y1":2,"x2":350,"y2":420,"duration":0.35}' > /dev/null
sleep 2
ssh root@192.168.0.190 "notifyutil -p com.futur3sn0w.ccaster/media-probe"
sleep 2
ssh root@192.168.0.190 "cat /var/mobile/Documents/CCAster-media-probe.log" || echo NO_LOG
