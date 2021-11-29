#!/usr/bin/env bash

set -e -u -o pipefail

SOCKET="unix-connect:/run/openvpn.sock"
RUN_AS=abc

[[ -f /etc/openvpn/utils.sh ]] && source /etc/openvpn/utils.sh || true

#Functions

# Handle SIGTERM
sigterm() {
  echo "Received SIGTERM, exiting..."
  trap - SIGTERM
  kill -- -$$
}
trap sigterm SIGTERM

#Network check
# Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks,
# therefore we use this script to catch error code 2
HOST=${HEALTH_CHECK_HOST}

if [[ -z "$HOST" ]]; then
  echo "Host  not set! Set env 'HEALTH_CHECK_HOST'. For now, using default google.com"
  HOST="google.com"
fi

# Check DNS resolution works
nslookup $HOST >/dev/null
STATUS=$?
if [[ ${STATUS} -ne 0 ]]; then
  echo "DNS resolution failed"
  exit 1
fi

ping -c 2 -w 10 $HOST # Get at least 2 responses and timeout after 10 seconds
STATUS=$?
if [[ ${STATUS} -ne 0 ]]; then
  echo "Network is down, stopping openvpn"
  echo signal SIGTERM | socat -s - ${SOCKET}
  exit 1
fi

echo "Network is up"

#Service check
#Expected output is 2 for both checks, 1 for process and 1 for grep
OPENVPN=$(pgrep openvpn | wc -l)
TRANSMISSION=$(pgrep transmission | wc -l)
PROXY=$(pgrep privoxy | wc -l)

if [[ ${OPENVPN} -ne 1 ]]; then
  echo "Openvpn process not running"
  exit 1
fi

LOAD=$(echo "load-stats" | socat -s - ${SOCKET} | tail -1)
STATE=$(echo "state" | socat -s - ${SOCKET} | sed -n '2p')
if [[ ! ${STATE} =~ CONNECTED ]]; then
  log "HEALTHCHECK: INFO: Openvpn load: ${LOAD}"
  log "HEALTHCHECK: ERROR: Openvpn not connected"
  exit 1
fi

if [[ "true" = "$LOG_TO_STDOUT" ]]; then
  LOGFILE=/dev/stdout
else
  LOGFILE=${TRANSMISSION_HOME}/transmission.log
fi

if [[ ${TRANSMISSION} -ne 1 ]]; then
  echo "transmission-daemon process not running"
  exec su --preserve-environment ${RUN_AS} -s /bin/bash -c "/usr/bin/transmission-daemon -g ${TRANSMISSION_HOME} --logfile $LOGFILE" &
  sleep 1
  [[ $(pgrep transmission | wc -l) -ne 1 ]] && echo "sigterm" | socat -s - ${SOCKET} && exit 1
fi

if [[ ${WEBPROXY_ENABLED,,} =~ (yes|true) ]]; then
  if [[ ${PROXY} -eq 0 ]]; then
    echo "Privoxy warning: process was stopped, restarting."
  fi
  # change privoxy listening address if needed.
  changePrivoxyListenAddress
fi

echo "Openvpn and transmission-daemon processes are running"
exit 0
