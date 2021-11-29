#!/bin/bash

set -e
DEBUG=${DEBUG:-"false"}
[[ ${DEBUG} != "false" ]] && set -x

#Change timzeone if set
[[ -n ${TZ} ]] && [[ -e /usr/share/zoneinfo/${TZ} ]] && [[ -w /etc/localtime ]] && rm -f /etc/localtime && ln -s /usr/share/zoneinfo/${TZ} /etc/localtime

# Source our persisted env variables from container startup
. /etc/transmission/environment-variables.sh

# Re-create `--up` command arguments to maintain compatibility with old user scripts
USER_SCRIPT_ARGS=("$dev" "$tun_mtu" "$link_mtu" "$ifconfig_local" "$ifconfig_remote" "$script_context")
[[ -n $1 ]] && [[ -z ${dev} ]] && dev=$1
[[ -n $2 ]] && [[ -z ${tun_mtu} ]] && tun_mtu=$2
[[ -n $3 ]] && [[ -z ${link_mtu} ]] && link_mtu=$3
[[ -n $4 ]] && [[ -z ${ifconfig_local} ]] && ifconfig_local=$4
[[ -n $5 ]] && [[ -z ${ifconfig_remote} ]] && ifconfig_remote=$5
[[ -n $6 ]] && [[ -z ${script_context} ]] && script_context=$6

# This script will be called with tun/tap device name as parameter 1, and local IP as parameter 4
# See https://openvpn.net/index.php/open-source/documentation/manuals/65-openvpn-20x-manpage.html (--up cmd)
#echo "Up script executed with $*"
echo "transmission start script executed with ${USER_SCRIPT_ARGS[*]}"
echo "0: ${USER_SCRIPT_ARGS[0]}"
echo "1: ${USER_SCRIPT_ARGS[1]}"
echo "2: ${USER_SCRIPT_ARGS[2]}"
echo "3: ${USER_SCRIPT_ARGS[3]}"
echo "4: ${USER_SCRIPT_ARGS[4]}"
if [[ "${ifconfig_local}" == "" ]]; then
  echo "ERROR, unable to obtain tunnel address"
  echo "killing $PPID"
  kill -9 $PPID
  exit 1
fi

# Re-create `--up` command arguments to maintain compatibility with old user scripts
USER_SCRIPT_ARGS=("$dev" "$tun_mtu" "$link_mtu" "$ifconfig_local" "$ifconfig_remote" "$script_context")

# If transmission-pre-start.sh exists, run it
SCRIPT=/etc/scripts/transmission-pre-start.sh
if [[ -x ${SCRIPT} ]]; then
  echo "Executing ${SCRIPT}"
  #${SCRIPT} "$@"
  ${SCRIPT} "${USER_SCRIPT_ARGS[*]}"
  echo "${SCRIPT} returned $?"
fi

echo "Updating TRANSMISSION_BIND_ADDRESS_IPV4 to the ip of ${dev} : ${ifconfig_local}"
export TRANSMISSION_BIND_ADDRESS_IPV4=${ifconfig_local}
# Also update the persisted settings in case it is already set. First remove any old value, then add new.
sed -i '/TRANSMISSION_BIND_ADDRESS_IPV4/d' /etc/transmission/environment-variables.sh
echo "export TRANSMISSION_BIND_ADDRESS_IPV4=${ifconfig_local}" >>/etc/transmission/environment-variables.sh

if [[ "combustion" = "$TRANSMISSION_WEB_UI" ]]; then
  echo "Using Combustion UI, overriding TRANSMISSION_WEB_HOME"
  export TRANSMISSION_WEB_HOME=/opt/transmission-ui/combustion-release
fi

if [[ "kettu" = "$TRANSMISSION_WEB_UI" ]]; then
  echo "Using Kettu UI, overriding TRANSMISSION_WEB_HOME"
  export TRANSMISSION_WEB_HOME=/opt/transmission-ui/kettu
fi

if [[ "transmission-web-control" = "$TRANSMISSION_WEB_UI" ]]; then
  echo "Using Transmission Web Control UI, overriding TRANSMISSION_WEB_HOME"
  export TRANSMISSION_WEB_HOME=/opt/transmission-ui/transmission-web-control
fi

if [[ "flood-for-transmission" = "$TRANSMISSION_WEB_UI" ]]; then
  echo "Using Flood for Transmission UI, overriding TRANSMISSION_WEB_HOME"
  export TRANSMISSION_WEB_HOME=/opt/transmission-ui/flood-for-transmission
fi

if [[ "shift" = "$TRANSMISSION_WEB_UI" ]]; then
  echo "Using Shift UI, overriding TRANSMISSION_WEB_HOME"
  export TRANSMISSION_WEB_HOME=/opt/transmission-ui/shift
fi

. /etc/transmission/userSetup.sh

echo "Updating Transmission settings.json with values from env variables"
# Ensure TRANSMISSION_HOME is created
mkdir -p ${TRANSMISSION_HOME}
python3 /etc/transmission/updateSettings.py /etc/transmission/default-settings.json ${TRANSMISSION_HOME}/settings.json || exit 1

echo "sed'ing True to true"
sed -i 's/True/true/g' ${TRANSMISSION_HOME}/settings.json

if [[ ! -e "/dev/random" ]]; then
  # Avoid "Fatal: no entropy gathering module detected" error
  echo "INFO: /dev/random not found - symlink to /dev/urandom"
  ln -s /dev/urandom /dev/random
fi

if [[ "true" = "$DROP_DEFAULT_ROUTE" ]]; then
    echo "DROPPING DEFAULT ROUTE"
    # Remove the original default route to avoid leaks.
    /sbin/ip route del default via "${route_net_gateway}" || exit 1
fi

if [[ "true" = "$LOG_TO_STDOUT" ]]; then
  LOGFILE=/dev/stdout
else
  LOGFILE=${TRANSMISSION_HOME}/transmission.log
fi

echo "STARTING TRANSMISSION"
exec su --preserve-environment ${RUN_AS} -s /bin/bash -c "/usr/bin/transmission-daemon -g ${TRANSMISSION_HOME} --logfile $LOGFILE" &

# Configure port forwarding if applicable
if [[ -x /etc/openvpn/${OPENVPN_PROVIDER,,}/update-port.sh && (-z $DISABLE_PORT_UPDATER || "false" = "$DISABLE_PORT_UPDATER") ]]; then
  echo "Provider ${OPENVPN_PROVIDER^^} has a script for automatic port forwarding. Will run it now."
  echo "If you want to disable this, set environment variable DISABLE_PORT_UPDATER=true"
  exec /etc/openvpn/${OPENVPN_PROVIDER,,}/update-port.sh &
fi

# If transmission-post-start.sh exists, run it
SCRIPT=/etc/scripts/transmission-post-start.sh
if [[ -x ${SCRIPT} ]]; then
  echo "Executing ${SCRIPT}"
  ${SCRIPT} "${USER_SCRIPT_ARGS[*]}"
  echo "${SCRIPT} returned $?"
fi

echo "Transmission startup script complete."
