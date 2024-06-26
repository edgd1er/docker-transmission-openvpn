#!/usr/bin/env bash
#used to build container or debian package for transmission.

#Variables
localDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DKRFILE=${localDir}/Dockerfile
ARCHI=$(dpkg --print-architecture)
IMAGE=transmission-openvpn
DUSER=edgd1er
aptCacher=$(ip route get 1 | awk '{print $7}')
[[ "${ARCHI}" != "armhf" ]] && isMultiArch=$(docker buildx ls | grep -c arm)
PROGRESS=auto  #text auto plain
PROGRESS=plain #text auto plain
CACHE=""
#CACHE="--no-cache"
#WHERE="--load"
#push
WHERE="--push"
TBT_VERSION=$(shell grep -oP '(?<= TBT_VERSION: ).+' .github/workflows/check_version.yml )
#TBT_VERSION=dev
#exit on error
set -xe

#fonctions
enableMultiArch() {
  if [[ -z $(docker buildx ls | grep amd-arm) ]]; then
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    #docker buildx rm amd-arm
    docker buildx create --use --name amd-arm --driver-opt image=moby/buildkit:master --platform=linux/amd64,linux/arm64,linux/386,linux/arm/v7,linux/arm/v6
    docker buildx inspect --bootstrap amd-arm
  else
    echo "amd arm instance already created. run 'docker buildx rm amd-arm' to recreate it at next run"
    docker buildx use amd-arm
  fi
}

getImageName() {
  if [[ $TBT_VERSION == dev ]]; then
    TAG="${IMAGE}:${TBT_VERSION%%.*}"
  else
    TAG="${IMAGE}:tbt_v${TBT_VERSION%%.*}"
  fi

  if [ "docker_login" != ${DUSER} ]; then
    TAG="${DUSER}/${TAG}"
  fi
  echo ${TAG}
}

getPlateforms() {
  if [ "${ARCHI}" == "armhf" ]; then
    PTF=linux/arm/v7
  else
    PTF=linux/amd64
    if [[ $isMultiArch -gt 0 ]] && [[ ${WHERE} != "--load" ]]; then
      PTF=linux/arm,linux/arm64,linux/amd64
      enableMultiArch >/dev/null
    fi
  fi
  echo $PTF
}

#Main
[[ "$HOSTNAME" != holdom3 ]] && aptCacher=""
[[ ! -f ${DKRFILE} ]] && echo -e "\nError, Dockerfile is not found\n" && exit 1
[[ $isMultiArch -eq 0 ]] && echo -e "\nbuildx builder is not mutli arch (arm + x86_64)\n"

TAG=$(getImageName)
PTF=$(getPlateforms)

# when building multi arch, load is not possible
[[ $PTF =~ , ]] && WHERE="--push"

echo -e "\nbuilding $TAG using cache $CACHE and apt cache $aptCacher \n\n"

#for TBT_VERSION in dev 4 3; do

TAG=$(getImageName)
# c= container, p=package
todo=${1:-c}
todo=${todo#-}
for ((i = 0; i < ${#todo}; i++)); do
  case ${todo:$i:1} in
  v)
    echo verbose mode
    set -x
    ;;
  p)
    echo Suppression de packages existants
    find out/ -type f -print -delete
    [[ phoebe == ${HOSTNAME} ]] && PTF=amd64
    echo generating debian package for ${PTF}
    docker buildx build --platform ${PTF} -f ${DKRFILE}.deb --build-arg TBT_VERSION=$TBT_VERSION $CACHE \
      --progress $PROGRESS --build-arg aptCacher=$aptCacher -o out .
    find out/ -mindepth 2 -type f -print -exec mv {} out/ \;
    ;;
  c)
    echo building images
    if [[ ! -f transmission-${TBT_VERSION}.tar.xz ]]; then curl -o transmission-${TBT_VERSION}.tar.xz -Lv ${URL}; fi
    docker buildx build ${WHERE} --platform ${PTF} -f ${DKRFILE} --build-arg TBT_VERSION=$TBT_VERSION \
      $CACHE --progress $PROGRESS --build-arg aptCacher=$aptCacher -t $TAG .
    #done
    docker manifest inspect $TAG | grep -E "architecture|variant"
    ;;
  *) ;;
  esac
done
