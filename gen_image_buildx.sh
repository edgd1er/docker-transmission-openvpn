#!/usr/bin/env bash

#Variables
localDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DKRFILE=${localDir}/Dockerfile
ARCHI=$(dpkg --print-architecture)
IMAGE=docker-transmission-openvpn
DUSER=docker_login
[[ "${ARCHI}" != "armhf" ]] && isMultiArch=$(docker buildx ls | grep -c arm)
aptCacher=$(ip route get 1 | awk '{print $7}')
#PROGRESS=plain  #text auto plain
PROGRESS=auto #text auto plain
CACHE=""
#CACHE="--no-cache"
WHERE="--load"
#push
#WHERE="--push"

#exit on error
set -xe

#fonctions
enableMultiArch() {
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  docker buildx rm amd-arm
  docker buildx create --use --name amd-arm --driver-opt image=moby/buildkit:master --platform=linux/amd64,linux/arm64,linux/386,linux/arm/v7,linux/arm/v6
  docker buildx inspect --bootstrap amd-arm
}

#Main
[[ "$HOSTNAME" =~ holdom ]] && aptCacher=""
[[ ! -f ${DKRFILE} ]] && echo -e "\nError, Dockerfile is not found\n" && exit 1
[[ $isMultiArch -eq 0 ]] && echo -e "\nbuildx builder is not mutli arch (arm + x86_64)\n"

if [ "docker_login" == ${DUSER} ]; then
  TAG="${IMAGE}:latest"
else
  TAG="${DUSER}/${IMAGE}:latest"
fi

if [ "${ARCHI}" == "armhf" ]; then
  PTF=linux/arm/v7
else
  PTF=linux/amd64
  [[ $isMultiArch -gt 0 ]] && [[ ${WHERE} != "--load" ]] && PTF=linux/arm/v7,linux/arm/v6,linux/amd64 && enableMultiArch
fi

# when building multi arch, load is not possible
[[ $PTF =~ , ]] && WHERE="--push"

echo -e "\nbuilding $TAG using cache $CACHE and apt cache $aptCacher \n\n"

docker buildx build ${WHERE} --platform ${PTF} -f ${DKRFILE} --build-arg REVISION=$VERSION \
  $CACHE --progress $PROGRESS --build-arg aptCacher=$aptCacher -t $TAG .

docker manifest inspect $TAG | grep -E "architecture|variant"
