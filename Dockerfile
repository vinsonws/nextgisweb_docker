FROM ubuntu:22.04 as build

# if you need a proxy , exec "docker build  -t {image} . --network host"
# or remove it.
ENV http_proxy http://192.168.1.101:1080
ENV https_proxy http://192.168.1.101:1080

ENV DEBIAN_FRONTEND noninteractive
ENV NEXTGISWEB_CONFIG /opt/nextgis/config/config.ini

WORKDIR /opt/nextgis
ENV VIRTUAL_ENV="/opt/nextgis/env"
ENV PATH="/opt/nextgis/env/bin/:$PATH"
ENV NODE_VERSION=v16.17.0
ENV DISTRO=linux-x64

RUN apt update && apt install curl git  apt-transport-https gnupg  software-properties-common -y && curl --silent https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - \
    && curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && add-apt-repository --yes --no-update "deb https://dl.yarnpkg.com/debian/ stable main" \
    && apt update && apt install python3 python3-dev python3-virtualenv \
    build-essential libssl-dev libgdal-dev libgeos-dev \
    gdal-bin libxml2-dev libxslt1-dev zlib1g-dev libjpeg-turbo8-dev \
    postgresql-client libmagic-dev yarn python3-mapscript \
    libqgis-dev qt5-image-formats-plugins build-essential cmake -y \
    && mkdir -p /opt/nextgis/config /opt/nextgis/data /opt/nextgis/package  /opt/nextgis/dist \
    && virtualenv -p /usr/bin/python3 /opt/nextgis/env \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*  
COPY config/config.ini /opt/nextgis/config/config.ini
RUN mkdir -p /opt/node \
    && curl https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${DISTRO}.tar.xz | tar -xvJ -C /opt \
    && mv  /opt/node-${NODE_VERSION}-${DISTRO}/* /opt/node/ && rm -rf /opt/node-${NODE_VERSION}-${DISTRO} \
    && cd /opt/nextgis/package && git clone https://github.com/nextgis/nextgisweb.git \
    && cd /opt/nextgis/package/nextgisweb \
    && git checkout $(git tag -l '*.*.*' | tail -1) \
    && cd /opt/nextgis/package \
    && pip install --no-cache-dir -e nextgisweb/ \
    && cd /opt/nextgis/package \
    && git clone https://github.com/nextgis/nextgisweb_mapserver.git \
    && nextgisweb_mapserver/mapscript-to-env ../env/bin/python /usr/bin/python3 \
    && pip install --no-cache-dir  -e nextgisweb_mapserver/ \
    && cd /opt/nextgis/package \
    && git clone https://github.com/nextgis/nextgisweb_basemap.git \
    && pip install --no-cache-dir  -e nextgisweb_basemap/ \
    && cd /opt/nextgis/package \
    && git clone --recurse-submodules https://github.com/nextgis/nextgisweb_qgis.git \
    && pip install --no-cache-dir  -e nextgisweb_qgis/qgis_headless \
    && pip install --no-cache-dir  -e nextgisweb_qgis/ \
    && cd /opt/nextgis/package \
    && git clone https://github.com/nextgis/nextgisweb_filebucket.git \
    && pip install --no-cache-dir  -e nextgisweb_filebucket/ \
    && cd /opt/nextgis/package \
    && git clone https://github.com/nextgis/nextgisweb_formbuilder.git \
    && pip install --no-cache-dir  -e nextgisweb_formbuilder/ \
    && cd /opt/nextgis/package \
    && git clone https://github.com/nextgis/nextgisweb_i18n.git \
    # && cd /opt/nextgis/package \
    # && git clone https://github.com/nextgis/nextgisweb_catalog.git \
    # && pip install --no-cache-dir  -e nextgisweb_catalog/ \
    # && cd /opt/nextgis/package \
    # && git clone https://github.com/nextgis/nextgisweb_log.git \
    # && pip install --no-cache-dir  -e nextgisweb_log/ \
    && pip install uwsgi \
    && cd /opt/nextgis/ \
    && nextgisweb-i18n -p nextgisweb compile \
    && nextgisweb-i18n -p nextgisweb_basemap compile \
    && nextgisweb-i18n -p nextgisweb_formbuilder compile \
    && nextgisweb-i18n -p nextgisweb_mapserver compile \
    && nextgisweb-i18n -p nextgisweb_qgis compile \
    && nextgisweb jsrealm.install \
    && yarn run build 


FROM ubuntu:22.04
EXPOSE 8080

# if you need a proxy , exec "docker build  -t {image} . --network host"
# or remove it.
ENV http_proxy http://192.168.1.101:1080
ENV https_proxy http://192.168.1.101:1080
ENV DEBIAN_FRONTEND noninteractive
ENV NEXTGISWEB_CONFIG /opt/nextgis/config/config.ini

RUN apt update && apt install python3 python3-dev python3-virtualenv \
    build-essential libssl-dev libgdal-dev libgeos-dev \
    gdal-bin libxml2-dev libxslt1-dev zlib1g-dev libjpeg-turbo8-dev \
    postgresql-client libmagic-dev python3-mapscript \
    libqgis-dev qt5-image-formats-plugins build-essential cmake -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get remove --auto-remove -y python3-pip \
    && unset http_proxy && unset https_proxy

ENV http_proxy  ""
ENV https_proxy  ""
WORKDIR /opt/nextgis
ENV VIRTUAL_ENV="/opt/nextgis/env"
ENV PATH="/opt/node/bin:/opt/nextgis/env/bin:$PATH"

RUN rm -rf /opt/*
COPY --from=build /opt/ /opt/
COPY config/uwsgi.ini /opt/nextgis/uwsgi.ini

CMD nextgisweb initialize_db &&  uwsgi --ini uwsgi.ini