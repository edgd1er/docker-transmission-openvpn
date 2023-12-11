#!/bin/bash

set -e -u -o pipefail

# Source our persisted env variables from container startup
. /etc/transmission/environment-variables.sh
[[ -f /etc/openvpn/utils.sh ]] && source /etc/openvpn/utils.sh || true

set_debug(){
  #https://www.privoxy.org/user-manual/config.html
  #  debug     1 # Log the destination for each request. See also debug 1024.
  #  debug     2 # show each connection status
  #  debug     4 # show tagging-related messages
  #  debug     8 # show header parsing
  #  debug    16 # log all data written to the network
  #  debug    32 # debug force feature
  #  debug    64 # debug regular expression filters
  #  debug   128 # debug redirects
  #  debug   256 # debug GIF de-animation
  #  debug   512 # Common Log Format
  #  debug  1024 # Log the destination for requests Privoxy didn't let through, and the reason why.
  #  debug  2048 # CGI user interface
  #  debug  4096 # Startup banner and warnings.
  #  debug  8192 # Non-fatal errors
  #  debug 32768 # log all data read from the network
  #  debug 65536 # Log the applying actions
  if [[ -n ${PRIVOXY_DEBUG:-""} ]];then
    if [[ $(grep -c "^debug" ${PCONF}) -ne 0 ]]; then
      sed -i -E "s/debug\s+[0-9]+/debug ${PRIVOXY_DEBUG}/" ${PCONF}
    else
      echo "debug ${PRIVOXY_DEBUG}">>${PCONF}
    fi
  fi
}

set_port()
{
  re='^[0-9]+$'
  port=${1:-8118}
  if ! [[ ${port} =~ $re ]] ; then
    echo "Privoxy: ERROR. Supplied port ${port} is not a number" >&2; exit 1
  fi

  # Port: Specify the port which privoxy will listen on.  Please note
  # that should you choose to run on a port lower than 1024 you will need
  # to start privoxy using root.

  if test "${port}" -lt 1024
  then
    echo "privoxy: $1 is lower than 1024. Ports below 1024 are not permitted.";
    exit 1
  fi

  echo "Privoxy: Setting port to ${port}";

# Remove the listen-address for IPv6 for now. IPv6 compatibility should come later
  sed -i -E "s/^listen-address\s+\[\:\:1.*//" "$2"

  # Set the port for the IPv4 interface
  adr=$(ip -4  a show eth0| grep -oP "(?<=inet )([^/]+)")
  adr=${adr:-"0.0.0.0"}
  sed -i -E "s/^listen-address\s+[0-9]{1,3}.*/listen-address ${adr}:${port}/" "$2"

}

if [[ "${WEBPROXY_ENABLED}" = "true" ]]; then
  echo "Privoxy: Starting"
  echo "Privoxy: Using config file at $PCONF"
  set_port "${WEBPROXY_PORT:-8118}" "${PCONF}"
  set_debug

  [[ -f /opt/privoxy/pidfile ]] && pkill -F /opt/privoxy/pidfile 2>&1 || true
  /usr/sbin/privoxy --pidfile /opt/privoxy/pidfile ${PCONF} 2>&1
  sleep 1 # Give it one sec to start up, or at least create the pidfile

  if [[ -f /opt/privoxy/pidfile ]]; then
    privoxy_pid=$(</opt/privoxy/pidfile)
    echo "Privoxy: Running as PID $privoxy_pid"
  else
    echo "Privoxy: ERROR. Did not start correctly, outputting logs"
    echo
    cat /var/log/privoxy/logfile
    echo
  fi

fi
