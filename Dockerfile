FROM ubuntu:22.04

EXPOSE 8080
# if you need a proxy , exec "docker build  -t {image} . --network host"
ENV http_proxy http://192.168.1.101:1080
ENV https_proxy http://192.168.1.101:1080

ENV DEBIAN_FRONTEND noninteractive
ENV NEXTGISWEB_CONFIG /opt/nextgis/config/config.ini
RUN apt update
RUN apt install curl git  apt-transport-https gnupg  software-properties-common -y
RUN curl --silent https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN add-apt-repository --yes --no-update "deb https://deb.nodesource.com/node_14.x jammy main"
RUN curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN add-apt-repository --yes --no-update "deb https://dl.yarnpkg.com/debian/ stable main"
RUN apt update
RUN apt install python3 python3-dev python3-virtualenv  -y
RUN apt install build-essential libssl-dev libgdal-dev libgeos-dev \
    gdal-bin libxml2-dev libxslt1-dev zlib1g-dev libjpeg-turbo8-dev \
    postgresql-client libmagic-dev nodejs yarn python3-mapscript -y
RUN apt install libqgis-dev qt5-image-formats-plugins build-essential cmake -y
RUN apt-get clean

RUN mkdir -p /opt/nextgis
WORKDIR /opt/nextgis
RUN mkdir config data package dist
COPY config/config.ini config/config.ini
RUN virtualenv -p /usr/bin/python3 env 
ENV VIRTUAL_ENV="/opt/nextgis/env"
ENV PATH="/opt/nextgis/env/bin/:$PATH"
RUN cd package && git clone https://github.com/nextgis/nextgisweb.git \
    && cd nextgisweb \
    && git checkout $(git tag -l '*.*.*' | tail -1) \
    && cd ..\
    && pip install -e nextgisweb/ \
    && nextgisweb-i18n -p nextgisweb compile

RUN cd /opt/nextgis/package \
    && git clone https://github.com/nextgis/nextgisweb_mapserver.git \
    && nextgisweb_mapserver/mapscript-to-env ../env/bin/python /usr/bin/python3 \
    && pip install -e nextgisweb_mapserver/

RUN cd /opt/nextgis/package \
    && git clone https://github.com/nextgis/nextgisweb_basemap.git \
    && pip install -e nextgisweb_basemap/

RUN cd /opt/nextgis/package \
    && git clone --recurse-submodules https://github.com/nextgis/nextgisweb_qgis.git \
    && pip install -e nextgisweb_qgis/qgis_headless \
    && pip install -e nextgisweb_qgis/

RUN . env/bin/activate \
    && nextgisweb jsrealm.install\
    && yarn run build 

RUN unset http_proxy && unset https_proxy
CMD nextgisweb server