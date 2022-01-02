.PHONY: lint flake8 help all

# Use bash for inline if-statements in arch_patch target
SHELL:=bash

# Enable BuildKit for Docker build
export DOCKER_BUILDKIT:=1

MAKEPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PWD := $(dir $(MAKEPATH))
CONTAINERS := $(shell docker ps -a -q -f "name=transmission-openvpn*")

all: lint build

# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## generate help list
		# @$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# Fichiers/,/^# Base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'
		@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

lint: # lint dockerfile
		@echo "lint dockerfile ..."
		docker run --rm -i hadolint/hadolint < ./Dockerfile

build: # build container
		@echo "build image ..."
		docker buildx build --progress auto --load -f Dockerfile --build-arg LIBEVENT_VERSION=2.1.12-stable --build-arg TBT_VERSION=3.00 -t edgd1er/transmission-openvpn:latest .

buildnc: # build container with no cache
		@echo "build image without cache ..."
		docker buildx build --progress plain --load --no-cache -f Dockerfile  -t edgd1er/transmission-openvpn .


down: # stop and delete container
		@echo "stop and delete container"
		docker compose -f docker-compose-dev.yml down -v

up: # start container
		@echo "start container"
		docker compose -f docker-compose-dev.yml up

login: #exec bash
		@echo "login into container"
		docker compose -f docker-compose-dev.yml exec transmission bash