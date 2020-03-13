## ada/wisp application Dockerfile, with apache and php
FROM php:7.3-apache-stretch
LABEL maintainer="g.consorti@lynxlab.com"

COPY vhost.conf /etc/apache2/sites-available/000-default.conf
COPY php-config/ $PHP_INI_DIR/conf.d/

# Use the default production configuration
RUN apt-get update  && apt-get -y install git zip unzip libzip-dev libpng-dev libicu-dev libjpeg62-turbo-dev \
    libfreetype6-dev libxslt1-dev libbz2-dev libedit-dev default-mysql-client gettext-base libgd3 libgd-dev \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && pecl install igbinary && docker-php-ext-enable igbinary \
    && pecl install apcu && docker-php-ext-enable apcu \
    && printf "yes\nyes\nno\n" | pecl install redis && docker-php-ext-enable redis \
    && curl -sS http://getcomposer.org/installer | php -- --filename=composer \
    && chmod a+x composer \
    && mv composer /usr/local/bin/composer \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-configure intl && docker-php-ext-install intl \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-install zip mysqli pdo_mysql opcache shmop exif gettext sockets xsl bz2 readline \
    && chmod 777 -R /tmp && chmod o+t -R /tmp \
    && a2enmod rewrite && a2enmod headers

COPY wait-for-mysql.sh /usr/local/bin
COPY entrypoint.sh /usr/local/bin/
WORKDIR /var/www/html/app

VOLUME [ "/var/www/html/app/clients", "/var/www/html/app/config", "/var/www/html/app/docs", "/var/www/html/app/layout", "/var/www/html/app/log", "/var/www/html/app/services/media", "/var/www/html/app/upload_file/uploaded_files" ]

ENTRYPOINT [ "wait-for-mysql.sh", "entrypoint.sh", "docker-php-entrypoint" , "apache2-foreground" ]
