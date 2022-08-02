#!/usr/bin/env bash

SOCKET="unix-connect:/run/openvpn.sock"
[[ -f /etc/openvpn/utils.sh ]] && source /etc/openvpn/utils.sh || true

RUN_AS=abc

#Functions
getExtIp() {
  ip -4 a show tun | grep -oP "(?<=inet )([^/]+)"
}

getIntIp() {
  ip -4 a show eth0 | grep -oP "(?<=inet )([^/]+)"
}

getIntCidr() {
  ip -j a show eth0 | jq -r '.[].addr_info[0]|"\( .broadcast)/\(.prefixlen)"' | sed 's/255/0/g'
}

getPrivoxyListen() {
  grep -oP "(?<=^listen-address )[0-9\.]+" /etc/privoxy/config
}

changePrivoxyListenAddress() {
  listen_ip4=$(grep -oP '(?<=^listen-address ) *[0-9\.]+' /etc/privoxy/config)
  current_ip4=$(getIntIp)
  if [[ ! -z ${listen_ip4} ]] && [[ ! -z ${current_ip4} ]] && [[ ${listen_ip4} != ${current_ip4} ]]; then
    echo "Privoxy: changing listening address from ${listen_ip4} to ${current_ip4}"
    sed -i "s/${listen_ip4}/${current_ip4}/" /etc/privoxy/config
    /opt/privoxy/stop.sh
    sleep 1
    /opt/privoxy/start.sh
  fi
}

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

#change privoxy listening address if needed.
changePrivoxyListenAddress

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

echo "Openvpn and transmission-daemon processes are running"
exit 0
