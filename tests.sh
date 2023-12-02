#!/usr/bin/env bash

#vars
CPSE=docker-compose-dev.yml
PROXY_HOST="localhost"
SOCK_PORT=""   #2080 # proxy socks
TRANS_PORT=$(grep -oP "9[^:]+(?=:9)" ${CPSE}) # trans port
HTTP_PORT=$(grep -oP "88[^:]+(?=:8)" ${CPSE}) # proxy http
CONTAINER=transmission
#Common
FAILED=0
INTERVAL=4
BUILD=1

#Functions
buildAndWait() {
  echo "Stopping and removing running containers"
  docker compose -f ${CPSE} down -v
  echo "Building and starting image"
  docker compose -f ${CPSE} up -d --build
  echo "Waiting for the container to be up.(every ${INTERVAL} sec)"
  logs=""
  while [ 0 -eq $(echo $logs | grep -c "Initialization Sequence Completed") ]; do
    #while [ 0 -eq $(echo $logs | grep -c "exited: start_vpn (exit status 0; expected") ]; do
    logs="$(docker compose -f ${CPSE} logs)"
    sleep ${INTERVAL}
    ((n += 1))
    echo "loop: ${n}: $(docker compose logs | tail -1)"
    [[ ${n} -eq 15 ]] && break || true
  done
  docker compose logs
}

areProxiesPortOpened() {
  for PORT in ${HTTP_PORT} ${SOCK_PORT} ${TRANS_PORT}; do
    msg="Test connection to port ${PORT}: "
    if [ 0 -eq $(echo "" | nc -v -q 2 ${PROXY_HOST} ${PORT} 2>&1 | grep -c "] succeeded") ]; then
      msg+=" Failed"
      ((FAILED += 1))
    else
      msg+=" OK"
    fi
    echo -e "$msg"
  done
}

testProxies() {
  vpnIP=$(curl -m5 -sx http://${PROXY_HOST}:${HTTP_PORT} "https://ifconfig.me/ip")
  if [[ $? -eq 0 ]] && [[ ${myIp} != "${vpnIP}" ]] && [[ ${#vpnIP} -gt 0 ]]; then
    echo "http proxy (${HTTP_PORT}): IP is ${vpnIP}, mine is ${myIp}"
  else
    echo "Error, curl through http proxy (${HTTP_PORT}) to https://ifconfig.me/ip failed"
    echo "or IP (${myIp}) == vpnIP (${vpnIP})"
    (( FAILED += 1 ))
  fi

  #check detected ips
  if [[ -n ${SOCK_PORT} ]]; then
    vpnIP=$(curl -m5 -sqx socks5://${PROXY_HOST}:${SOCK_PORT} "https://ifconfig.me/ip")
    if [[ $? -eq 0 ]] && [[ ${myIp} != "${vpnIP}" ]] && [[ ${#vpnIP} -gt 0 ]]; then
      echo "socks proxy (${SOCK_PORT}): IP is ${vpnIP}, mine is ${myIp}"
    else
      echo "Error, curl through socks proxy (${SOCK_PORT}) to https://ifconfig.me/ip failed"
      echo "or IP (${myIp}) == vpnIP (${vpnIP})"
      ((FAILED += 1))
    fi
  fi
  echo "# failed tests: ${FAILED}"
}

getInterfacesInfo() {
  docker compose exec ${CONTAINER} bash -c "ip -j a |jq  '.[]|select(.ifname|test(\"wg0|tun|nordlynx\"))|.ifname'"
  itf=$(docker compose exec ${CONTAINER} ip -j a)
  echo eth0:$(echo $itf | jq -r '.[] |select(.ifname=="eth0")| .addr_info[].local')
  echo wg0: $(echo $itf | jq -r '.[] |select(.ifname=="wg0")| .addr_info[].local')
  echo nordlynx: $(echo $itf | jq -r '.[] |select(.ifname=="nordlynx")| .addr_info[].local')
  docker compose exec ${CONTAINER} bash -c 'echo "nordlynx conf: $(wg showconf nordlynx 2>/dev/null)"'
  docker compose exec ${CONTAINER} bash -c 'echo "wg conf: $(wg showconf wg0 2>/dev/null)"'
}

#Main
[[ -e /.dockerenv ]] && PROXY_HOST=

# arg -t test only
[[ ${1:-''} == "-t" ]] && BUILD=0 || BUILD=1
# external ip
myIp=$(curl -m5 -sq https://ifconfig.me/ip)

#build if localhost
if [[ "localhost" == "${PROXY_HOST}" ]] && [[ 1 -eq ${BUILD} ]]; then
  buildAndWait
fi
echo "***************************************************"
echo "Testing container"
echo "***************************************************"
# check returned IP through http and socks proxy
testProxies
getInterfacesInfo
[[ 1 -eq ${BUILD} ]] && docker compose down
