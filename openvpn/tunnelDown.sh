#!/bin/bash

set -e -u -o pipefail

#tunnel is down, restore resolv.conf to previous version
if compgen -G "/etc/resolv.conf-*.sv" ; then
    cp /etc/resolv.conf-*.sv /etc/resolv.conf
    echo "resolv.conf was restored"
else
    echo "resolv.conf backup not found, could not restore"
fi

/etc/transmission/stop.sh
[[ -f /opt/privoxy/stop.sh ]] && /opt/privoxy/stop.sh
