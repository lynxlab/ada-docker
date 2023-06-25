## ada/wisp application Dockerfile, with apache and php
#FROM php:7.3-apache-stretch
#FROM php:7.3-apache-buster
FROM debian:bullseye
LABEL maintainer="g.consorti@lynxlab.com"


ENV PACKAGES="php7.4 libapache2-mod-php7.4 git zip unzip default-mysql-client gettext-base libgd3 curl php-igbinary php-apcu php-redis php-gd php-intl php-opcache php-zip php-bz2 php-mysqli php-shmop php-exif php-php-gettext php-sockets php-xsl php-readline php-curl"

RUN apt-get update && apt-get -y install $PACKAGES && apt-get clean

#ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

#RUN chmod +x /usr/local/bin/install-php-extensions && \
#    install-php-extensions igbinary apcu redis gd intl opcache zip bz2 mysqli shmop exif gettext sockets xsl readline curl

#RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Use the default production configuration
# RUN apt-get update  && apt-get -y install git zip unzip libzip-dev libpng-dev libicu-dev libjpeg62-turbo-dev \
#     libfreetype6-dev libxslt1-dev libbz2-dev libedit-dev default-mysql-client gettext-base libgd3 libgd-dev \
#     && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
#     && pecl install igbinary && docker-php-ext-enable igbinary \
#     && pecl install apcu && docker-php-ext-enable apcu \
#     && printf "yes\nyes\nno\n" | pecl install redis && docker-php-ext-enable redis \
#     && curl -sS http://getcomposer.org/installer | php -- --filename=composer \
#     && chmod a+x composer \
#     && mv composer /usr/local/bin/composer \
#     && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
#     && docker-php-ext-install -j$(nproc) gd \
#     && docker-php-ext-configure intl && docker-php-ext-install intl \
#     && docker-php-ext-configure opcache --enable-opcache \
#     && docker-php-ext-install zip mysqli pdo_mysql opcache shmop exif gettext sockets xsl bz2 readline \
#     && chmod 777 -R /tmp && chmod o+t -R /tmp \
#     && a2enmod rewrite && a2enmod headers

RUN git config --global --add safe.directory /var/www/html/app

RUN  curl -sS http://getcomposer.org/installer | php -- --filename=composer \
     && chmod a+x composer \
     && mv composer /usr/local/bin/composer
COPY vhost.conf /etc/apache2/sites-available/000-default.conf
COPY php-config/ $PHP_INI_DIR/conf.d/

RUN  chmod 777 -R /tmp && chmod o+t -R /tmp \
     && a2enmod rewrite && a2enmod headers && a2enmod ssl

COPY wait-for-mysql.sh /usr/local/bin
COPY entrypoint.sh /usr/local/bin
COPY apache2-foreground /usr/local/bin
COPY docker-php-entrypoint /usr/local/bin
RUN  chmod +x /usr/local/bin/*

WORKDIR /var/www/html/app

VOLUME [ "/var/www/html/app" ]

ENTRYPOINT [ "wait-for-mysql.sh", "entrypoint.sh", "docker-php-entrypoint" , "apache2-foreground" ]
