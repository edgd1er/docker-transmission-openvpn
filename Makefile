.PHONY: lint flake8 help all

MAKEPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PWD := $(dir $(MAKEPATH))
CONTAINERS := $(shell docker ps -a -q -f "name=transmission-openvpn*")

help:
		@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# Fichiers/,/^# Base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

all: lint molecule flake8

lint:
		docker run --rm -i hadolint/hadolint < ./Dockerfile

build:
		docker buildx build --progress auto --load -f Dockerfile .

buildnc:
		docker buildx build --progress plain --load --no-cache -f Dockerfile .


down:
		docker-compose -f docker-compose.yml -f Dockerfile down -v

up:
		docker-compose -f Dockerfile up