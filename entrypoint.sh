#!/bin/bash
set -e

php << 'PHP'
<?php
$confVars = array(
  'database_driver',
  'database_host',
  'database_port',
  'database_name',
  'database_user',
  'database_password',
  'locale',
  'secret'
);

$path = 'app/config/parameters.yml';
$file = file_get_contents($path);
foreach ($confVars as $confVar) {
  $envVar = strtoupper($confVar);
  if (($envValue = getenv($envVar)) !== false) {
    $pattern = '/^(\s*' . preg_quote($confVar) . '):.+$/m';
    if (preg_match($pattern, $file)) {
      $file = preg_replace($pattern, '$1: ' . $envValue, $file, 1);
    } else {
      $file .= "    $confVar: $envValue\n";
    }
  }
}

file_put_contents($path, $file);
?>
PHP

if [ -z "$ENV" ]; then
  ENV="production"
fi

cp /usr/local/etc/php/custom.conf.d/$ENV.ini /usr/local/etc/php/conf.d/akeneo_pim.ini
echo "memory_limit=512M" >> /usr/local/etc/php/conf.d/akeneo_pim.ini

if [ ! -z "$ON_READY" ]; then
  eval "$ON_READY"
fi

echo "Waiting for database"
curl -sL "https://raw.githubusercontent.com/netresearch/retry/master/retry" -o /usr/local/bin/retry
chmod +x /usr/local/bin/retry
retry "mysql -e 'SELECT 1' -h $DATABASE_HOST -u $DATABASE_USER -p$DATABASE_PASSWORD $DATABASE_NAME"

php app/console cache:clear --env=prod

echo "Installing Akeneo"
if [ ! -d "app/archive/" ]; then
    mkdir app/archive/
fi

if [ ! -d "app/file_storage/catalog/" ]; then
    mkdir app/file_storage/
    mkdir app/file_storage/catalog/
fi

if [ ! -d "/tmp/pim/" ]; then
    mkdir /tmp/pim/
fi

if [ ! -d "/tmp/pim/file_storage/" ]; then
    mkdir /tmp/pim/file_storage/
fi

php app/console pim:installer:check-requirements --env=prod

if ! mysql -e 'Select 1 FROM pim_catalog_channel;' -h $DATABASE_HOST -u $DATABASE_USER -p$DATABASE_PASSWORD $DATABASE_NAME; then
    php app/console pim:installer:db --env=prod
fi

php app/console pim:installer:assets --env=prod

chown -R www-data /var/www/html
chown -R www-data /tmp/pim

$@
