#! /bin/bash

set -e -u -o pipefail

. /etc/transmission/environment-variables.sh
[[ -f /etc/openvpn/utils.sh ]] && source /etc/openvpn/utils.sh || true

# If transmission-pre-stop.sh exists, run it
if [[ -x /scripts/transmission-pre-stop.sh ]]
then
    echo "Executing /scripts/transmission-pre-stop.sh"
    /scripts/transmission-pre-stop.sh "$@"
    echo "/scripts/transmission-pre-stop.sh returned $?"
fi

PID=$(pidof transmission-daemon)
if [[ -n ${PID} ]]; then
  kill "$PID"
  echo "Sending kill signal to transmission-daemon"
else
  echo "No transmission-daemon to kill"
fi

# Give transmission-daemon some time to shut down
TRANSMISSION_TIMEOUT_SEC=${TRANSMISSION_TIMEOUT_SEC:-5}
for i in $(seq "$TRANSMISSION_TIMEOUT_SEC")
do
    sleep 1
    [[ -z "$(pidof transmission-daemon)" ]] && break
    [[ $i == 1 ]] && echo "Waiting ${TRANSMISSION_TIMEOUT_SEC}s for transmission-daemon to die"
done

# Check whether transmission-daemon is still running
if [[ -z "$(pidof transmission-daemon)" ]]
then
    echo "Successfuly closed transmission-daemon"
else
    echo "Sending kill signal (SIGKILL) to transmission-daemon"
    kill -9 "$PID"
fi

# If transmission-post-stop.sh exists, run it
if [[ -x /scripts/transmission-post-stop.sh ]]
then
    echo "Executing /scripts/transmission-post-stop.sh"
    /scripts/transmission-post-stop.sh "$@"
    echo "/scripts/transmission-post-stop.sh returned $?"
fi
