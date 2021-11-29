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

lint: ## lint dockerfile
		@echo "lint dockerfile ..."
		@docker run --rm -i hadolint/hadolint < ./Dockerfile

build3: ## build container transmission v3
		@echo "build image with transmission v3 ..."
		@docker buildx build --progress auto --load -f Dockerfile --build-arg aptCacher=192.168.53.208 --build-arg LIBEVENT_VERSION=2.1.12-stable --build-arg TBT_VERSION=3 -t edgd1er/transmission-openvpn:tbt_v3 .

build4: ## build container transmission v4
		@echo "build image with transmission v4 tagged..."
		@docker buildx build --progress auto --load -f Dockerfile --build-arg aptCacher=192.168.53.208 --build-arg LIBEVENT_VERSION=2.1.12-stable --build-arg TBT_VERSION=4 -t edgd1er/transmission-openvpn:tbt_v4 .

builddev: ## build container transmission dev
		@echo "build image with dev versions ..."
		@docker buildx build --progress auto --load -f Dockerfile --build-arg aptCacher=192.168.53.208 --build-arg LIBEVENT_VERSION=2.1.12-stable --build-arg TBT_VERSION=dev -t edgd1er/transmission-openvpn:dev .

buildnc: ## build container with no cache
		@echo "build image without cache ..."
		@docker buildx build --progress plain --load --no-cache -f Dockerfile  -t edgd1er/transmission-openvpn .


down: ## stop and delete container
		@echo "stop and delete container"
		docker compose -f docker-compose-dev.yml down -v

up: ## start container
		@echo "start container"
		docker compose -f docker-compose-dev.yml up

login: ## exec bash
		@echo "login into container"
		docker compose -f docker-compose-dev.yml exec transmission bash

nordvpn1: ##test nordvpn api calls: novalues
		@echo "test nordvpn api 1"
		OPENVPN_PROVIDER=NORDVPN NORDVPN_TESTS=1 DEBUG=false ./openvpn/nordvpn/configure-openvpn.sh

nordvpn2: ##test nordvpn api calls: no categories
		@echo "test nordvpn api 2"
		OPENVPN_PROVIDER=NORDVPN NORDVPN_TESTS=2 DEBUG=false ./openvpn/nordvpn/configure-openvpn.sh

nordvpn3: ##test nordvpn api calls: Incompatible_combinations
		@echo "test nordvpn api 3"
		OPENVPN_PROVIDER=NORDVPN NORDVPN_TESTS=3 DEBUG=false ./openvpn/nordvpn/configure-openvpn.sh

nordvpn4: ##test nordvpn api calls: get first us server
		@echo "test nordvpn api 4"
		OPENVPN_PROVIDER=NORDVPN NORDVPN_TESTS=4 DEBUG=false ./openvpn/nordvpn/configure-openvpn.sh

nordvpn: ##test nordvpn api calls: perform all tests
		@echo "test nordvpn api"
		OPENVPN_PROVIDER=NORDVPN NORDVPN_TESTS=1 DEBUG=false ./openvpn/nordvpn/configure-openvpn.sh
		OPENVPN_PROVIDER=NORDVPN NORDVPN_TESTS=2 DEBUG=false ./openvpn/nordvpn/configure-openvpn.sh
		OPENVPN_PROVIDER=NORDVPN NORDVPN_TESTS=3 DEBUG=false ./openvpn/nordvpn/configure-openvpn.sh
		OPENVPN_PROVIDER=NORDVPN NORDVPN_TESTS=4 DEBUG=false ./openvpn/nordvpn/configure-openvpn.sh