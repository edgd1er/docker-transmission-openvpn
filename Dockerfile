# syntax=docker/dockerfile:1
FROM debian:bullseye-slim as TransmissionUIs
ARG LIBEVENT_VERSION=2.1.12-stable
ARG TBT_VERSION=3.00
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#hadolint ignore=DL3018,DL3008
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libcurl4-openssl-dev libssl-dev \
     pkg-config build-essential checkinstall wget tar zlib1g-dev intltool jq bash
WORKDIR /var/tmp
#hadolint ignore=DL3003
RUN mkdir -p /var/tmp && cd /var/tmp && echo "getting libevent ${LIBEVENT_VERSION} and transmission ${TBT_VERSION}"\
    && wget --no-cache -O- https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz \
    | tar zx -C /var/tmp/ && mv libevent-${LIBEVENT_VERSION} libevent-${LIBEVENT_VERSION%%-*} \
    && cd /var/tmp/libevent-${LIBEVENT_VERSION%%-*} \
    && CFLAGS="-Os -march=native" ./configure && make -j2 \
    && sed -i 's/TRANSLATE=1/TRANSLATE=0/g' "/etc/checkinstallrc" && checkinstall -y \
    && ls -alh /var/tmp/libevent-${LIBEVENT_VERSION%%-*}/ \
    && mv /var/tmp/libevent-${LIBEVENT_VERSION%%-*}/*.deb /var/tmp/
#hadolint ignore=DL3003
RUN if [[ "3.00" != ${TBT_VERSION} ]]; then \
    wget --no-cache -qO- https://github.com/transmission/transmission-releases/raw/master/transmission-${TBT_VERSION}.tar.xz \
    | tar -Jx -C /var/tmp/ \
    && cd transmission-${TBT_VERSION} \
    && CFLAGS="-Os -march=native" ./configure --enable-lightweight && make -j2 && checkinstall -y -D \
    && cp /var/tmp/transmission-${TBT_VERSION}/*.deb /var/tmp/ ; fi

RUN mkdir -p /opt/transmission-ui \
    && echo "Install Shift" \
    && wget --no-cache -qO- https://github.com/killemov/Shift/archive/master.tar.gz | tar xz -C /opt/transmission-ui \
    && mv /opt/transmission-ui/Shift-master /opt/transmission-ui/shift \
    && echo "Install Flood for Transmission" \
    && wget --no-cache -qO- https://github.com/johman10/flood-for-transmission/releases/download/latest/flood-for-transmission.tar.gz | tar xz -C /opt/transmission-ui \
    && echo "Install Combustion" \
    && wget --no-cache -qO- https://github.com/Secretmapper/combustion/archive/release.tar.gz | tar xz -C /opt/transmission-ui \
    && echo "Install kettu" \
    && wget --no-cache -qO- https://github.com/endor/kettu/archive/master.tar.gz | tar xz -C /opt/transmission-ui \
    && mv /opt/transmission-ui/kettu-master /opt/transmission-ui/kettu \
    && echo "Install Transmission-Web-Control" \
    && mkdir /opt/transmission-ui/transmission-web-control \
    && wget --no-cache -qO- "$(wget --no-cache -qO- https://api.github.com/repos/ronggang/transmission-web-control/releases/latest | jq --raw-output '.tarball_url')" | tar -C /opt/transmission-ui/transmission-web-control/ --strip-components=2 -xz

FROM debian:bullseye-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG LIBEVENT_VERSION=2.1.12-stable
ARG TBT_VERSION=3.00
ARG TARGETPLATFORM

VOLUME /data
VOLUME /config

COPY --from=TransmissionUIs /opt/transmission-ui /opt/transmission-ui
COPY --from=TransmissionUIs /var/tmp/*.deb /var/tmp/

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#hadolint ignore=DL3008,SC2046
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common && \
    apt-add-repository non-free && apt-get update && apt-get install -y --no-install-recommends \
    dumb-init openvpn transmission-daemon transmission-cli privoxy procps socat xz-utils\
    tzdata dnsutils iputils-ping ufw openssh-client git jq curl wget unrar unzip bc \
    && echo "cpu: ${TARGETPLATFORM}" \
    && if [[ "3.00" != ${TBT_VERSION} ]]; then \
    echo "Installing transmission v3 local build" && ls -alh /var/tmp/*.deb \
    && dpkg -i /var/tmp/libevent_${LIBEVENT_VERSION%%-*}-1_$(dpkg --print-architecture).deb \
    && dpkg -i /var/tmp/transmission_${TBT_VERSION}-1_$(dpkg --print-architecture).deb \
    else echo "Installing transmission v3 from repository" \
    && apt-get install -y --no-install-recommends transmission-daemon transmission-cli; fi \
    && ln -s /usr/share/transmission/web/style /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/images /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/javascript /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/index.html /opt/transmission-ui/transmission-web-control/index.original.html \
    && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* \
    && groupmod -g 1000 users \
    && useradd -u 911 -U -d /config -s /bin/false abc \
    && usermod -G users abc


# Add configuration and scripts
COPY openvpn/ /etc/openvpn/
COPY privoxy/scripts /opt/privoxy/
COPY scripts /etc/scripts/
COPY transmission/ /etc/transmission/
#Add a script to test dnsleeak https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.sh
#ADD https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.sh /etc/scripts/

ENV OPENVPN_USERNAME=**None** \
    OPENVPN_PASSWORD=**None** \
    OPENVPN_PROVIDER=**None** \
    OPENVPN_OPTS= \
    GLOBAL_APPLY_PERMISSIONS=true \
    TRANSMISSION_WEB_UI=transmission-web-control \
    TRANSMISSION_HOME=/config/transmission-home \
    TRANSMISSION_RPC_PORT=9091 \
    TRANSMISSION_RPC_USERNAME="" \
    TRANSMISSION_RPC_PASSWORD="" \
    TRANSMISSION_DOWNLOAD_DIR=/data/completed \
    TRANSMISSION_INCOMPLETE_DIR=/data/incomplete \
    TRANSMISSION_WATCH_DIR=/data/watch \
    CREATE_TUN_DEVICE=true \
    ENABLE_UFW=false \
    UFW_ALLOW_GW_NET=false \
    UFW_EXTRA_PORTS='' \
    UFW_DISABLE_IPTABLES_REJECT=false \
    PUID=''\
    PGID='' \
    PEER_DNS=true \
    PEER_DNS_PIN_ROUTES=true \
    DROP_DEFAULT_ROUTE='' \
    WEBPROXY_ENABLED=false \
    WEBPROXY_PORT=8118 \
    WEBPROXY_USERNAME='' \
    WEBPROXY_PASSWORD='' \
    LOG_TO_STDOUT=false \
    HEALTH_CHECK_HOST=google.com \
    SELFHEAL=false

HEALTHCHECK --start-period=60s --interval=1m --retries=4 CMD /etc/scripts/healthcheck.sh

# Add labels to identify this image and version
ARG REVISION
# Set env from build argument or default to empty string
ENV REVISION=${REVISION:-""}
LABEL org.opencontainers.image.source=https://github.com/haugene/docker-transmission-openvpn
LABEL org.opencontainers.image.revision=$REVISION

# Compatability with https://hub.docker.com/r/willfarrell/autoheal/
LABEL autoheal=true

# Expose port and run
#Transmission-RPC
EXPOSE 9091
# Privoxy
EXPOSE 8118

CMD ["dumb-init", "/etc/openvpn/start.sh"]