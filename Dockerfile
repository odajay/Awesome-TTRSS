FROM alpine:3 AS builder

# Download ttrss via git
WORKDIR /var/www
RUN apk add --update tar curl git \
  && rm -rf /var/www/* \
  && git clone https://git.tt-rss.org/fox/tt-rss --depth=1 /var/www \
  && cp config.php-dist config.php


# Download plugins
WORKDIR /var/temp

## Fever
RUN mkdir /var/www/plugins/fever && \
  curl -sL https://github.com/HenryQW/tinytinyrss-fever-plugin/archive/master.tar.gz | \
  tar xzvpf - --strip-components=1 -C /var/www/plugins/fever tinytinyrss-fever-plugin-master

## Mercury Fulltext
RUN mkdir /var/www/plugins/mercury_fulltext && \
  curl -sL https://github.com/HenryQW/mercury_fulltext/archive/master.tar.gz | \
  tar xzvpf - --strip-components=1 -C /var/www/plugins/mercury_fulltext mercury_fulltext-master

## Feediron
RUN mkdir /var/www/plugins/feediron && \
  curl -sL https://github.com/feediron/ttrss_plugin-feediron/archive/master.tar.gz | \
  tar xzvpf - --strip-components=1 -C /var/www/plugins/feediron ttrss_plugin-feediron-master

## OpenCC
RUN mkdir /var/www/plugins/opencc && \
  curl -sL https://github.com/HenryQW/ttrss_opencc/archive/master.tar.gz | \
  tar xzvpf - --strip-components=1 -C /var/www/plugins/opencc ttrss_opencc-master

# ## News+ API
RUN mkdir /var/www/plugins/api_newsplus && \
  curl -sL https://github.com/voidstern/tt-rss-newsplus-plugin/archive/master.tar.gz | \
  tar xzvpf - --strip-components=2 -C /var/www/plugins/api_newsplus  tt-rss-newsplus-plugin-master/api_newsplus

## FeedReader API
ADD https://raw.githubusercontent.com/jangernert/FeedReader/master/data/tt-rss-feedreader-plugin/api_feedreader/init.php /var/www/plugins/api_feedreader/

## Options per feed
RUN mkdir /var/www/plugins/options_per_feed && \
  curl -sL https://github.com/sergey-dryabzhinsky/options_per_feed/archive/master.tar.gz | \
  tar xzvpf - --strip-components=1 -C /var/www/plugins/options_per_feed options_per_feed-master

## Remove iframe sandbox
RUN mkdir /var/www/plugins/remove_iframe_sandbox && \
  curl -sL https://github.com/DIYgod/ttrss-plugin-remove-iframe-sandbox/archive/master.tar.gz | \
  tar xzvpf - --strip-components=1 -C /var/www/plugins/remove_iframe_sandbox ttrss-plugin-remove-iframe-sandbox-master

## Wallabag
RUN mkdir /var/www/plugins/wallabag_v2 && \
  curl -sL https://github.com/joshp23/ttrss-to-wallabag-v2/archive/master.tar.gz | \
  tar xzvpf - --strip-components=2 -C /var/www/plugins/wallabag_v2 ttrss-to-wallabag-v2-master/wallabag_v2

## Feedly
RUN curl -sL https://github.com/levito/tt-rss-feedly-theme/archive/master.tar.gz | \
  tar xzvpf - --strip-components=1 --wildcards -C /var/www/themes.local tt-rss-feedly-theme-master/feedly*.css

## RSSHub
RUN curl -sL https://github.com/DIYgod/ttrss-theme-rsshub/archive/master.tar.gz | \
  tar xzvpf - --strip-components=2 -C /var/www/themes.local ttrss-theme-rsshub-master/dist/rsshub.css

FROM alpine:3

LABEL maintainer="Henry<hi@henry.wang>"

WORKDIR /var/www

COPY src/wait-for.sh /wait-for.sh
COPY src/ttrss.nginx.conf /etc/nginx/nginx.conf
COPY src/configure-db.php /configure-db.php
COPY src/s6/ /etc/s6/

ENV SELF_URL_PATH http://localhost:181
ENV DB_NAME ttrss
ENV DB_USER ttrss
ENV DB_PASS ttrss

# Install dependencies
RUN chmod -x /wait-for.sh && apk add --update --no-cache git nginx s6 curl \
  php7 php7-intl php7-fpm php7-cli php7-curl php7-fileinfo \
  php7-mbstring php7-gd php7-json php7-dom php7-pcntl php7-posix \
  php7-pgsql php7-mcrypt php7-session php7-pdo php7-pdo_pgsql \
  ca-certificates && rm -rf /var/cache/apk/* \
  # Update libiconv as the default version is too low
  && apk add gnu-libiconv --update-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted \
  && rm -rf /var/www 

# Copy TTRSS and plugins
COPY --from=builder /var/www /var/www

ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php

# Install GNU libc (aka glibc) and set C.UTF-8 locale as default.
# https://github.com/Docker-Hub-frolvlad/docker-alpine-glibc/blob/master/Dockerfile

ENV LANG=C.UTF-8

RUN ALPINE_GLIBC_BASE_URL="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" && \
  ALPINE_GLIBC_PACKAGE_VERSION="2.31-r0" && \
  ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
  ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
  ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
  apk add --no-cache --virtual=.build-dependencies wget && \
  wget https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -O /etc/apk/keys/sgerrand.rsa.pub && \
  wget \
  "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
  "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
  "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
  apk add --no-cache \
  "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
  "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
  "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
  \
  rm "/etc/apk/keys/sgerrand.rsa.pub" && \
  /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true && \
  echo "export LANG=$LANG" > /etc/profile.d/locale.sh && \
  \
  apk del glibc-i18n && \
  \
  rm "/root/.wget-hsts" && \
  apk del .build-dependencies && \
  rm -rf /var/cache/apk/* && \
  rm \
  "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
  "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
  "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
  chown nobody:nginx -R /var/www

EXPOSE 80

CMD php /configure-db.php && exec s6-svscan /etc/s6/
