FROM php:5.6.25-apache

RUN apt-get update \
    && apt-get upgrade -y -o Dpkg::Options::="--force-confnew" --no-install-recommends \
    && apt-get install -y -o Dpkg::Options::="--force-confnew" --no-install-recommends git nano libicu-dev libmcrypt-dev libpng-dev libcurl3-dev libxml2-dev libjpeg-dev libpng-dev libssl-dev mysql-client \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure gd --enable-gd-native-ttf --with-jpeg-dir=/usr/lib/x86_64-linux-gnu --with-png-dir=/usr/lib/x86_64-linux-gnu \
    && docker-php-ext-install mbstring pdo_mysql mysqli intl mcrypt gd exif curl soap zip opcache bcmath \
    && pecl install -f mongo \
    && pecl install apcu-4.0.11 \
    && docker-php-ext-enable mongo apcu \
    && apt-get autoremove \
    && apt-get clean -y \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/* \
    && for logs in `find /var/log -type f`; do > $logs; done \
    && rm -rf /usr/share/locale/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /var/cache/apt/*.bin

RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && mkdir /usr/local/etc/php/cli \
    && mkdir /usr/local/etc/php/cli/conf.d \
    && echo apc.enable_cli=1 > /usr/local/etc/php/cli/conf.d/enable-apc-cli.ini

COPY php.ini /usr/local/etc/php/php.ini
COPY php.ini /usr/local/etc/php/cli/php.ini
COPY php.custom.conf.d /usr/local/etc/php/custom.conf.d
COPY vhost.conf /etc/apache2/sites-available/akeneo_pim.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN mkdir -p /var/www
RUN cd /var/www && rm -rf html && curl -sL http://download.akeneo.com/pim-community-standard-v1.6-latest.tar.gz | tar -xz && mv pim* html

RUN a2enmod rewrite \
    && a2ensite akeneo_pim \
    && a2dissite 000-default.conf

WORKDIR /var/www/html

EXPOSE 80

VOLUME /tmp/pim

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
