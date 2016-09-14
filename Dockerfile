FROM php:7.0.10-apache

RUN apt-get update \
    && apt-get upgrade -y -o Dpkg::Options::="--force-confnew" --no-install-recommends \
    && apt-get install -y -o Dpkg::Options::="--force-confnew" --no-install-recommends git ssh nano libicu-dev libmcrypt-dev libpng-dev libcurl3-dev libxml2-dev libjpeg-dev libpng-dev libssl-dev mysql-client pkg-config \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure gd --enable-gd-native-ttf --with-jpeg-dir=/usr/lib/x86_64-linux-gnu --with-png-dir=/usr/lib/x86_64-linux-gnu \
    && docker-php-ext-install mbstring pdo_mysql mysqli intl mcrypt gd exif curl soap zip opcache bcmath \
    && pecl install -f mongodb \
    && pecl install apcu \
    && docker-php-ext-enable mongodb apcu \
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

COPY setup/ /

RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && echo apc.enable_cli=1 > /usr/local/etc/php/cli/conf.d/enable-apc-cli.ini

RUN mkdir -p /var/www
RUN cd /var/www && rm -rf html && curl -sL http://download.akeneo.com/pim-community-standard-v1.6-latest.tar.gz | tar -xz && mv pim* html

RUN a2enmod rewrite \
    && a2ensite akeneo_pim \
    && a2dissite 000-default.conf

RUN cd /var/www/html \
    && composer config github-oauth.github.com "9b5a6885f569e34684746977c239c66001c15e17" \
    && composer install --optimize-autoloader --prefer-dist \
    && composer require alcaeus/mongo-php-adapter --ignore-platform-reqs \
    && composer --prefer-dist require doctrine/mongodb-odm-bundle 3.2.0 \
    && composer config --unset github-oauth.github.com

RUN cd /var/www/html \
    && ssh-keyscan -t rsa bitbucket.org >> ~/.ssh/known_hosts \
    && chmod 700 ~/.ssh/id_rsa \
    && sed -ri 's!"repositories": \[!"repositories": \[\{"type": "vcs","url": "git@bitbucket.org:netresearch/netresearch_metricexpander.git"\},!' composer.json \
    && sed -ri 's!"repositories": \[!"repositories": \[\{"type": "vcs","url": "git@bitbucket.org:netresearch/blfgroup_theme.git"\},!' composer.json \
    && sed -ri 's!"require": \{!"require": \{"netresearch/metric-expander": "dev-master",!' composer.json \
    && sed -ri 's!"require": \{!"require": \{"netresearch/blf-theme": "dev-master",!' composer.json

RUN cd /var/www/html \
    && rm -Rf app/cache/* \
    && composer update \
    && sed -ri 's!\/\/ your app bundles should be registered here!\/\/ your app bundles should be registered here\n new Netresearch\\Bundle\\MetricExpanderBundle\\NrMetricsBundle\(\),!' app/AppKernel.php \
    && sed -ri 's!\/\/ your app bundles should be registered here!\/\/ your app bundles should be registered here\n new Netresearch\\Bundle\\UIBundle\\NetresearchUIBundle\(\),!' app/AppKernel.php \
    && sed -ri "s/^(\s*)\/\/ (.*)DoctrineMongoDBBundle\(\),/\1\2DoctrineMongoDBBundle(),/" app/AppKernel.php


WORKDIR /var/www/html

EXPOSE 80

VOLUME /tmp/pim /var/www/html/app/cache /var/www/html/app/file_storage /var/www/html/app/logs /var/log/apache2 /root/.composer/cache

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
