# syntax=docker/dockerfile:1.3
FROM debian:bookworm-slim as base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#hadolint ignore=DL3018,DL3008,DL3009
RUN  if [[ -n ${aptcacher} ]]; then echo "Acquire::http::Proxy \"http://${aptcacher}:3142\";" >/etc/apt/apt.conf.d/01proxy; \
    echo "Acquire::https::Proxy \"http://${aptcacher}:3142\";" >>/etc/apt/apt.conf.d/01proxy ; fi; \
    apt-get update && apt-get install -y --no-install-recommends software-properties-common \
    && apt-add-repository non-free && apt-get update && apt-get install -y --no-install-recommends \
    dumb-init openvpn privoxy procps socat libevent-2.1-7 libnatpmp1 libminiupnpc17 unrar-free \
    tzdata dnsutils iputils-ping ufw openssh-client git jq curl wget unzip bc libdeflate0 iproute2

#hadolint ignore=DL3007
FROM alpine:latest as TransmissionUIs

SHELL ["/bin/ash", "-o", "pipefail", "-c"]
#Transmission web control
ARG verWC=1.6.33
ARG verTC=1.8.0
#hadolint ignore=DL3018,DL3008
RUN apk --no-cache add curl jq && mkdir -p /opt/transmission-ui \
    && echo "Install Shift" \
    && wget -qO- https://github.com/killemov/Shift/archive/master.tar.gz | tar xz -C /opt/transmission-ui \
    && mv /opt/transmission-ui/Shift-master /opt/transmission-ui/shift
RUN echo "Install Flood for Transmission" \
    && wget -qO- https://github.com/johman10/flood-for-transmission/releases/download/latest/flood-for-transmission.tar.gz | tar xz -C /opt/transmission-ui
RUN echo "Install Combustion" \
    && wget -qO- https://github.com/Secretmapper/combustion/archive/release.tar.gz | tar xz -C /opt/transmission-ui
RUN echo "Install kettu" \
    && wget -qO- "https://github.com/endor/kettu/archive/master.tar.gz" | tar xz -C /opt/transmission-ui \
    && mv /opt/transmission-ui/kettu-master /opt/transmission-ui/kettu
RUN echo "Install Transmission-Web-Control" \
    && sleep 10 \
    && mkdir -p /opt/transmission-ui/transmission-web-control/ \
    #&& curl -sL $(curl -s https://api.github.com/repos/ronggang/transmission-web-control/releases/latest | jq --raw-output '.tarball_url') | tar -C /opt/transmission-ui/transmission-web-control/ --strip-components=2 -xz \
    && wget -q -O- "https://github.com/transmission-web-control/transmission-web-control/releases/download/v${verWC}/dist.tar.gz" | tar -C /opt/transmission-ui/transmission-web-control/ --strip-components=2 -xz
RUN echo "Install Transmissionic ${verTC}" \
    && wget -qO- "https://github.com/6c65726f79/Transmissionic/releases/download/v${verTC}/Transmissionic-webui-v${verTC}.zip" | unzip -d /opt/transmission-ui/ -
#    && mv /opt/transmission-ui/web /opt/transmission-ui/transmissionic \
RUN  rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

FROM base

ARG DEBIAN_FRONTEND=noninteractive
ARG TBT_VERSION=4.0.5
ARG TARGETPLATFORM

VOLUME /data
VOLUME /config

COPY --from=TransmissionUIs /opt/transmission-ui /opt/transmission-ui
#COPY --from=devbase /var/tmp/*.deb /var/tmp/
COPY out/*.deb /var/tmp/

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

#hadolint ignore=DL3008,DL3009,SC2046
RUN echo "cpu: ${TARGETPLATFORM}" && \
    if [[ "${TBT_VERSION}" =~ ^4 ]]; then \
      ARCH="$(dpkg --print-architecture)" \
      # && ls -alh /var/tmp/transmission_${TBT_VERSION}*_${ARCH}.deb \
      && debfile=$(compgen -G /var/tmp/transmission_${TBT_VERSION}*_${ARCH}.deb) ;\
      if [[ -n "${debfile}" ]]; then \
      echo "Installing transmission ${TBT_VERSION}: ${debfile}" && dpkg -i ${debfile} && dpkg -c ${debfile} \
      && ln -s /usr/local/share/transmission/public_html/images /opt/transmission-ui/transmission-web-control/ \
      && ln -s /usr/local/share/transmission/public_html/transmission-app.js /opt/transmission-ui/transmission-web-control/transmission-app.js \
      && ln -s /usr/local/share/transmission/public_html/index.html /opt/transmission-ui/transmission-web-control/index.original.html ;\
      else echo "No /var/tmp/transmission_${TBT_VERSION}*_${ARCH}.deb. Exiting" ; exit ; fi ; \
    else echo "Installing transmission from repository" ;\
    export TBT_VERSION=3.00 \
    && apt-get install -y --no-install-recommends transmission-daemon transmission-cli\
    && ln -s /usr/share/transmission/web/style /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/images /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/javascript /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/index.html /opt/transmission-ui/transmission-web-control/index.original.html \
    ; fi \
    && groupmod -g 1000 users \
    && useradd -u 911 -U -d /config -s /bin/false abc \
    && usermod -G users abc \
    && echo "alias checkip='curl -sm 10 \"https://zx2c4.com/ip\"'" | tee -a ~/.bashrc \
    && echo "alias checkhttp='curl -sm 10 -x http://\${HOSTNAME}:\${WEBPROXY_PORT:-8888} \"https://ifconfig.me/ip\";echo'" | tee -a ~/.bashrc \
    && echo "alias checkvpn='curl -sm 10 \"https://api.nordvpn.com/vpn/check/full\" | jq -r .status'" | tee -a ~/.bashrc \
    && echo "alias getcheck='curl -sm 10 \"https://api.nordvpn.com/vpn/check/full\" | jq . '" | tee -a ~/.bashrc \
    && echo "alias gettrans='grep bind /config/transmission-home/settings.json'|jq ." | tee -a ~/.bashrc \
    && echo "alias getpriv='grep -vP \"(^$|^#)\" /etc/privoxy/config'" | tee -a ~/.bashrc \
    && echo "alias dltest='curl http://ipv4.bouygues.testdebit.info/10M.iso -o /dev/null'" | tee -a ~/.bashrc \
    && echo "alias ll='ls -al '" | tee -a ~/.bashrc \
    && echo "alias modalias='vim ~/.bashrc'" | tee -a ~/.bashrc \
    && echo "alias salias='source ~/.bashrc'" | tee -a ~/.bashrc


# Add configuration and scripts
COPY openvpn/ /etc/openvpn/
COPY privoxy/scripts /opt/privoxy/
COPY scripts /etc/scripts/
COPY transmission/ /etc/transmission/
#Add a script to test dnsleeak https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.sh
#ADD https://raw.githubusercontent.com/macvk/dnsleaktest/master/dnsleaktest.sh /etc/scripts/

# Support legacy IPTables commands
RUN update-alternatives --set iptables "$(which iptables-legacy)" && \
    update-alternatives --set ip6tables "$(which ip6tables-legacy)"

ENV OPENVPN_USERNAME=**None** \
    OPENVPN_PASSWORD=**None** \
    OPENVPN_PROVIDER=**None** \
    OPENVPN_OPTS='' \
    OPENVPN_LOGLEVEL='' \
    OPENVPN_CONFIG_URL=''\
    GLOBAL_APPLY_PERMISSIONS=true \
    TRANSMISSION_LOG_LEVEL=info \
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

# Pass revision as a build arg, set it as env var
ARG REVISION
ENV REVISION=${REVISION:-""}

# Compatability with https://hub.docker.com/r/willfarrell/autoheal/
LABEL autoheal=true

# Expose port and run
#Transmission-RPC
EXPOSE 9091
# Privoxy
EXPOSE 8118

CMD ["dumb-init", "/etc/openvpn/start.sh"]