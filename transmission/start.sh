#!/bin/bash

set -e -u -o pipefail

[[ -f /etc/openvpn/utils.sh ]] && source /etc/openvpn/utils.sh || true

# Source our persisted env variables from container startup
. /etc/transmission/environment-variables.sh

# Re-create `--up` command arguments to maintain compatibility with old user scripts
USER_SCRIPT_ARGS=("${dev:-}" "${tun_mtu:-}" "${link_mtu:-}" "${ifconfig_local:-}" "${ifconfig_remote:-}" "${script_context:-}")
[[ -z ${dev:-} ]] && dev=${1:-}
[[ -z ${tun_mtu:-} ]] && tun_mtu=${2:-}
[[ -z ${link_mtu:-} ]] && link_mtu=${3:-}
[[ -z ${ifconfig_local:-} ]] && ifconfig_local=${4:-}
[[ -z ${ifconfig_remote:-} ]] && ifconfig_remote=${5:-}
[[ -z ${script_context:-} ]] && script_context=${6:-}

# This script will be called with tun/tap device name as parameter 1, and local IP as parameter 4
# See https://openvpn.net/index.php/open-source/documentation/manuals/65-openvpn-20x-manpage.html (--up cmd)
#echo "Up script executed with $*"
echo "transmission start script executed with ${USER_SCRIPT_ARGS[*]}"
echo "0:dev=${USER_SCRIPT_ARGS[0]}"
echo "1:tun_mtu=${USER_SCRIPT_ARGS[1]}"
echo "2:link_mtu=${USER_SCRIPT_ARGS[2]}"
echo "3:local ip=${USER_SCRIPT_ARGS[3]}"
echo "4:remote_ip=${USER_SCRIPT_ARGS[4]}"
echo "5:script_context=${USER_SCRIPT_ARGS[4]}"
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

TRANSMISSION_LOG_LEVEL=${TRANSMISSION_LOG_LEVEL:-info}

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

if [[ "transmissionic" = "$TRANSMISSION_WEB_UI" ]]; then
  echo "Using Transmissionic UI, overriding TRANSMISSION_WEB_HOME"
  export TRANSMISSION_WEB_HOME=/opt/transmission-ui/transmissionic
fi

case ${TRANSMISSION_LOG_LEVEL,,} in
  "trace" | "debug" | "info" | "warn" | "error" | "critical")
    echo "Will exec Transmission with '--log-level=${TRANSMISSION_LOG_LEVEL,,}' argument"
    export TRANSMISSION_LOGGING="--log-level=${TRANSMISSION_LOG_LEVEL,,}"
    ;;
  *)
    export TRANSMISSION_LOGGING=""
    ;;
esac

. /etc/transmission/userSetup.sh
if [[ -z $TRANSMISSION_WEB_UI ]]; then
  echo "Defaulting TRANSMISSION_WEB_HOME to Transmission Web Control UI"
  export TRANSMISSION_WEB_HOME=/opt/transmission-ui/transmission-web-control
fi

echo "Updating Transmission settings.json with values from env variables"
# Ensure TRANSMISSION_HOME is created
mkdir -p ${TRANSMISSION_HOME}

. /etc/transmission/userSetup.sh

su --preserve-environment ${RUN_AS} -s /usr/bin/python3 /etc/transmission/updateSettings.py /etc/transmission/default-settings.json ${TRANSMISSION_HOME}/settings.json || exit 1
echo "sed'ing True to true"
su --preserve-environment ${RUN_AS} -c "sed -i 's/True/true/g' ${TRANSMISSION_HOME}/settings.json"
setNewUSer

if [[ ! -e "/dev/random" ]]; then
  # Avoid "Fatal: no entropy gathering module detected" error
  echo "INFO: /dev/random not found - symlink to /dev/urandom"
  ln -s /dev/urandom /dev/random
fi

if [[ "true" = "$DROP_DEFAULT_ROUTE" ]]; then
    echo "DROPPING DEFAULT ROUTE"
    # Remove the original default route to avoid leaks.
    eval $(/sbin/ip route list match 0.0.0.0 | awk '{if($5!="tun0"){print "GW="$3"\nINT="$5; exit}}')
    [[ -z ${GW:-''} ]] && echo "No default gateway found" || /sbin/ip route del default via "${GW}"
fi

if [[ "true" = "$LOG_TO_STDOUT" ]]; then
  LOGFILE=/dev/stdout
else
  LOGFILE=${TRANSMISSION_HOME}/transmission.log
fi

if [[ -f /usr/local/bin/transmission-daemon ]]; then
  transbin='/usr/local/bin'
else
  transbin='/usr/bin'
fi
echo "STARTING TRANSMISSION"
exec su --preserve-environment ${RUN_AS} -s /bin/bash -c "${transbin}/transmission-daemon ${TRANSMISSION_LOGGING} -g ${TRANSMISSION_HOME} --logfile $LOGFILE" &

exec su --preserve-environment ${RUN_AS} -s /bin/bash -c "/usr/local/bin/transmission-daemon ${TRANSMISSION_LOGGING} -g ${TRANSMISSION_HOME} --logfile $LOGFILE" &


# Configure port forwarding if applicable
if [[ -f /etc/openvpn/${OPENVPN_PROVIDER,,}/update-port.sh && (-z $DISABLE_PORT_UPDATER || "false" = "$DISABLE_PORT_UPDATER") ]]; then
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
