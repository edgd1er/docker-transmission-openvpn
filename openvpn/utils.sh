#!/bin/bash

export PCONF=/etc/privoxy/config
export DEBUG=${DEBUG:-"false"}
[[ ${DEBUG} != "false" ]] && set -x || true

#Functions
log() {
  #printf "${TIME_FORMAT} %b\n" "$*" >/dev/stderr
  printf "%b\n" "$*" >/dev/stderr
}

fatal_error() {
  #printf "${TIME_FORMAT} \e[41mERROR:\033[0m %b\n" "$*" >&2
  printf "\e[41mERROR:\033[0m %b\n" "$*" >&2
  exit 1
}

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
  grep -oP "(?<=^listen-address )[0-9\.]+" ${PCONF}
}

changePrivoxyListenAddress() {
  listen_ip4=$(getPrivoxyListen)
  current_ip4=$(getIntIp)
  if [[ ! -z ${listen_ip4} ]] && [[ ! -z ${current_ip4} ]] && [[ ${listen_ip4} != ${current_ip4} ]]; then
    echo "Privoxy: changing listening address from ${listen_ip4} to ${current_ip4}"
    sed -i "s/${listen_ip4}/${current_ip4}/" ${PCONF}
    /opt/privoxy/stop.sh
    sleep 1
    /opt/privoxy/start.sh
  fi
}

getLatestTransmissionWebUI() {
  newVer=$(curl -s "https://api.github.com/repos/transmission-web-control/transmission-web-control/releases/latest" | jq -r .tag_name )
  wget --no-cache -qO- "https://github.com/transmission-web-control/transmission-web-control/releases/download/${newVer}/dist.tar.gz" | tar -C /opt/transmission-ui/transmission-web-control/ --strip-components=2 -xz
}