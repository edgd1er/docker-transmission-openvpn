#!/bin/bash
# Source our persisted env variables from container startup

. /etc/transmission/environment-variables.sh
[[ -f /etc/openvpn/utils.sh ]] && source /etc/openvpn/utils.sh || true

if [[ "${WEBPROXY_ENABLED}" = "true" ]]; then

  pkill privoxy

fi
