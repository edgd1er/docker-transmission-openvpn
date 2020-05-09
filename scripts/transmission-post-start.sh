#!/usr/bin/with-contenv bash

dockerize -template /etc/transmission/settings.tmpl:${TRANSMISSION_HOME}/settings.json
sed '/blocklist-url/ s#\&#\\&#' ${TRANSMISSION_HOME:-config}/settings.json


BLOCKLIST_ENABLED=$(jq -r '.["blocklist-enabled"]' /${TRANSMISSION_HOME:-config}/settings.json)
[[ true == ${BLOCKLIST_ENABLED} ]] && [[ -n "${TRANSMISSION_BLOCKLIST_URL}" ]] && echo "Updating: ${TRANSMISSION_BLOCKLIST_URL}" || exit

if [ "$BLOCKLIST_ENABLED" == true ] && [ -n "${TRANSMISSION_BLOCKLIST_URL}" ]; then
  TR=$(echo ${TRANSMISSION_BLOCKLIST_URL} | sed "s#&#\\\&# ")
  sed -i '/blocklist-url/ s#:.*$#: \"'${TR}'\",#g' /${TRANSMISSION_HOME:-config}/settings.json
  /usr/bin/transmission-remote -exit

  if [ -n "${TRANSMISSION_RPC_USERNAME}" ] && [ -n "${TRANSMISSION_RPC_PASSWORD}" ]; then
    /usr/bin/transmission-remote -n "$USER":"$PASS" --blocklist-update
  else
    /usr/bin/transmission-remote --blocklist-update
  fi
fi
