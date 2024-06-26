#!/bin/bash

#
# This script tries to figure out how the container is configured.
# The user has two options:
# 1. Mount a custom config file to be used
# 2. Use the built in template that supports one feed with regex filter
#

set -e -u -o pipefail

# Source our persisted env variables from container startup
. /etc/transmission/environment-variables.sh
[[ -f /etc/openvpn/utils.sh ]] && source /etc/openvpn/utils.sh || true

if [ -f /etc/transmission-rss.conf ] ; then
  echo "Found mounted /etc/transmission-rss.conf file"
elif [ -z "${RSS_URL}" ] || [ "${RSS_URL}" = "**None**" ] ; then
  echo "Error: No config is mounted and RSS_URL is not defined."
  echo "Have no config to start from. Exit with error code."
  exit 1
else
  # The RSS url can (and usually does) contain special chars. We need to escape them
  rss_url_esc=$(printf '%q' "$RSS_URL")
  rss_regex_esc=$(printf '%q' "$RSS_REGEXP")

  # Configure plugin based on template. Use sed to insert 
    sed "s^url: placeholder^url: $rss_url_esc^" < /etc/transmission-rss/transmission-rss.tmpl \
    | sed "s^download_path: placeholder^download_path: $TRANSMISSION_DOWNLOAD_DIR^" \
    > /etc/transmission-rss.conf

  if [ -z "${RSS_REGEXP}" ] ; then
    sed -i '/regexp/d' /etc/transmission-rss.conf
  else
    sed -i "s#regexp: placeholder#regexp: $rss_regex_esc#" /etc/transmission-rss.conf
  fi
  if [[ $TRANSMISSION_RPC_ENABLED == 'true' ]] && [ -z $(grep login /etc/transmission-rss.conf) ]; then
    echo "RPC enabled, adding login details to rss config as no login details exist"
    printf "login:\n  username: $TRANSMISSION_RPC_USERNAME\n  password: $TRANSMISSION_RPC_PASSWORD" >>/etc/transmission-rss.conf
  else
    echo "Login already provided in config OR RPC does not seem to be enabled"
  fi
fi

echo "Starting RSS plugin with the following config:"
echo
cat /etc/transmission-rss.conf

echo
transmission-rss
