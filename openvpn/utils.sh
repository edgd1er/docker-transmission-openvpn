#!/bin/bash

DEBUG=${DEBUG:-"false"}
[[ ${DEBUG} != "false" ]] && set -x || true

log() {
  #printf "${TIME_FORMAT} %b\n" "$*" >/dev/stderr
  printf "%b\n" "$*" >/dev/stderr
}

fatal_error() {
  #printf "${TIME_FORMAT} \e[41mERROR:\033[0m %b\n" "$*" >&2
  printf "\e[41mERROR:\033[0m %b\n" "$*" >&2
  exit 1
}