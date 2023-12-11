#!/usr/bin/env bash

set -e -o pipefail
#vars
GITHUB_TOKEN=
LIBEVENT_VERSION=$(grep -oP "(?<= LIBEVENT_VERSION: )[^$]+" .github/workflows/check_version.yml | tr -d '"')
TRANSMISSION_VERSION=$(grep -oP "(?<= TBT_VERSION: )[^$]+" .github/workflows/check_version.yml | tr -d '"')
TRANSMISSION_DEV_VERSION=$(grep -oP "(?<= DEV_VERSION: )[^$]+" .github/workflows/check_version.yml | tr -d '"')
TICV=$(grep -oP "(?<= TC_VERSION: )[^$]+" .github/workflows/check_version.yml | tr -d '"')
WC_VERSION=$(grep -oP "(?<= WC_VERSION: )[^$]+" .github/workflows/check_version.yml | tr -d '"')

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

[[ -n ${GITHUB_TOKEN} ]] && HEADERTOKEN=-H\ \'Authorization:\ Bearer\ ${GITHUB_TOKEN}\' || HEADERTOKEN=""

#Functions
checkLibEvent() {
  ver=$(curl -s ${HEADERTOKEN} "https://api.github.com/repos/libevent/libevent/releases/latest" | jq -r .tag_name )
  [[ release-${LIBEVENT_VERSION} == ${ver} ]] && coul=${GREEN} || coul=${RED}
  echo -e "libevent build version: ${coul}${LIBEVENT_VERSION}${NC}, latest github libevent version: ${coul}${ver}${NC}"
}

checkTbt(){
  ver=$(curl -s ${HEADERTOKEN} "https://api.github.com/repos/transmission/transmission/releases/latest" | jq -r .tag_name )
  [[ ${TRANSMISSION_VERSION} == ${ver} ]] && coul=${GREEN} || coul=${RED}
  echo -e "transmission build version: ${coul}${TRANSMISSION_VERSION}${NC}, latest: ${coul}${ver}${NC}"
  devver=$(curl -s "https://raw.githubusercontent.com/transmission/transmission/main/CMakeLists.txt" | grep -oP "(?<=TR_VERSION_(MAJOR|MINOR|PATCH) \")[^\"]+" | tr '\n' '.' | grep -oP "[0-9]+\.[0-9]+\.[0-9]+")
  [[ ${TRANSMISSION_DEV_VERSION} == ${devver} ]] && coul=${GREEN} || coul=${RED}
  echo -e "transmission dev build version: ${coul}${TRANSMISSION_DEV_VERSION}${NC}, latest: ${coul}${devver}${NC}"
}

checkUIs(){
  ver=$(curl -s ${HEADERTOKEN} "https://api.github.com/repos/6c65726f79/Transmissionic/releases/latest" | jq -r .tag_name)
  [[ v${TICV} == ${ver} ]] && coul=${GREEN} || coul=${RED}
  echo -e "Transmissionic version: ${coul}${TICV}${NC}, latest: ${coul} ${ver}${NC}"
  ver=$(curl -s ${HEADERTOKEN} "https://api.github.com/repos/transmission-web-control/transmission-web-control/releases/latest" | jq -r .tag_name)
  [[ v${WC_VERSION} == ${ver} ]] && coul=${GREEN} || coul=${RED}
  echo -e "transmission-web-control version: ${coul}${WC_VERSION}${NC}, latest: ${coul} ${ver}${NC}"
}

#Main
checkLibEvent
checkTbt
checkUIs