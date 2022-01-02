# OpenVPN and Transmission with WebUI

![Docker build](https://github.com/edgd1er/docker-transmission-openvpn/workflows/Docker%20CI%20buildx%20armhf+amd64/badge.svg)
![Docker Size](https://badgen.net/docker/size/edgd1er/transmission-openvpn/latest/amd64?icon=docker&label=Size)
![Docker Pulls](https://badgen.net/docker/pulls/edgd1er/transmission-openvpn?icon=docker&label=Pulls)
![Docker Stars](https://badgen.net/docker/stars/edgd1er/transmission-openvpn?icon=docker&label=Stars)
![ImageLayers](https://badgen.net/docker/layers/edgd1er/transmission-openvpn?icon=docker&label=Layers)

[![Join the chat at https://gitter.im/docker-transmission-openvpn/Lobby](https://badges.gitter.im/transmission-openvpn/Lobby.svg)](https://gitter.im/docker-transmission-openvpn/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fkylemanna%2Fdocker-openvpn.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Fkylemanna%2Fdocker-openvpn?ref=badge_shield)

this fork of [haugene](https://github.com/haugene/docker-transmission-openvpn) has very few changes from the original. the main purpose is to test ahead of time some changes.
- use transmission v3.0, instead of 2.94. (for tbt_v3 branch)
- use debian:bullseye-slim
- add dnsleaktest.sh from https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.sh (no automatic check)
- pre/post start scripts location moved from /scripts to /etc/scripts, add dnsleak report on post transmission start
- kill openvpn through [management port](https://github.com/OpenVPN/openvpn/blob/master/doc/management-notes.txt) if healthcheck is failing.
- healthcheck: check ping, openvpn running, transmission running
- credentials: use docker secrets to transfer user/password to container.
--------------------------------------------------------------------------------

This container contains OpenVPN and Transmission with a configuration
where Transmission is running only when OpenVPN has an active tunnel.
It has built in support for many popular VPN providers to make the setup easier.

## Read this first

The documentation for this image is hosted on GitHub pages:

https://haugene.github.io/docker-transmission-openvpn/

If you can't find what you're looking for there, please have a look
in the [discussions](https://github.com/haugene/docker-transmission-openvpn/discussions)
as we're trying to use that for general questions.

If you have found what you believe to be an issue or bug, create an issue and provide
enough details for us to have a chance to reproduce it or undertand what's going on.
**NB:** Be sure to search for similar issues (open and closed) before opening a new one.

## Quick Start

These examples shows valid setups using PIA as provider for both
docker run and docker-compose. Note that you should read some documentation
at some point, but this is a good place to start.

### Docker run

```
$ docker run --cap-add=NET_ADMIN -d \
              -v /your/storage/path/:/data \
              -e OPENVPN_PROVIDER=PIA \
              -e OPENVPN_CONFIG=france \
              -e OPENVPN_USERNAME=user \
              -e OPENVPN_PASSWORD=pass \
              -e LOCAL_NETWORK=192.168.0.0/16 \
              --log-driver json-file \
              --log-opt max-size=10m \
              -p 9091:9091 \
              haugene/transmission-openvpn
```

### Docker Compose
```
version: '3.3'
services:
    transmission-openvpn:
        cap_add:
            - NET_ADMIN
        volumes:
            - '/your/storage/path/:/data'
        environment:
            - OPENVPN_PROVIDER=PIA
            - OPENVPN_CONFIG=france
            - OPENVPN_USERNAME=user
            - OPENVPN_PASSWORD=pass
            - LOCAL_NETWORK=192.168.0.0/16
        logging:
            driver: json-file
            options:
                max-size: 10m
        ports:
            - '9091:9091'
        image: haugene/transmission-openvpn
```

## Please help out (about:maintenance)
This image was created for my own use, but sharing is caring, so it had to be open source.
It has now gotten quite popular, and that's great! But keeping it up to date, providing support, fixes
and new features takes time. If you feel that you're getting a good tool and want to support it, there are a couple of options:

A small montly amount through [![Donate with Patreon](images/patreon.png)](https://www.patreon.com/haugene) or
a one time donation with [![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=73XHRSK65KQYC)

All donations are greatly appreciated! Another great way to contribute is of course through code.
A big thanks to everyone who has contributed so far!
