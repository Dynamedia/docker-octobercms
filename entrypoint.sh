#!/bin/bash

# Run the entrypoint script that comes with the web server image to set up the environment
nginx-fpm-entrypoint.sh

# Setup October CMS
OC_APP_DEBUG=${OC_APP_DEBUG:-true}
OC_APP_KEY=${OC_APP_KEY:-}
OC_APP_URL=${OC_APP_URL:-http://localhost}
OC_DB_CONNECTION=${OC_DB_CONNECTION:-sqlite}
OC_DB_HOST=${OC_DB_CONNECTION:-mysql}
OC_DB_PORT=${OC_DB_PORT:-3306}
OC_DB_DATABASE=${OC_DB_DATABASE:-october}
OC_DB_USERNAME=${OC_DB_USERNAME:-october}
OC_DB_PASSWORD=${OC_DB_PASSWORD:-october}
OC_REDIS_HOST=${OC_REDIS_HOST:-redis}
OC_REDIS_PASSWORD=${OC_REDIS_PASSWORD:-}
OC_CACHE_DRIVER=${OC_CACHE_DRIVER:-file}
OC_SESSION_DRIVER=${OC_SESSION_DRIVER:-file}
OC_QUEUE_DRIVER=${OC_QUEUE_DRIVER:-sync}
OC_MAIL_DRIVER=${OC_MAIL_DRIVER:-mail}
OC_MAIL_HOST=${OC_MAIL_HOST:-smtp.mailgun.org}
OC_MAIL_PORT=${OC_MAIL_PORT:-587}
OC_MAIL_ENCRYPTION=${OC_MAIL_ENCRYPTION:-tls}
OC_MAIL_USERNAME=${OC_MAIL_USERNAME:-null}
OC_MAIL_PASSWORD=${OC_MAIL_PASSWORD:-null}
OC_ROUTES_CACHE=${OC_ROUTES_CACHE:-false}
OC_ASSET_CACHE=${OC_ASSET_CACHE:-false}
OC_LINK_POLICY=${OC_LINK_POLICY:-detect}
OC_ENABLE_CSRF=${OC_ENABLE_CSRF:-true}
OC_FRESH_INSTALL=${OC_FRESH_INSTALL:-false}


# Generate a key before we create a .env file so it gets carried over
if [ -z $OC_APP_KEY ] & [ ! -f ".env" ] ; then
    php artisan key:generate
fi

# Make sure we have a .env file to edit or nothing is going to work properly
if [ ! -f .env ] ; then
    php artisan october:env
fi


# If we're using sqlite (the default), make sure we have a file to use
if [ "$OC_DB_CONNECTION" = "sqlite" ] ; then
    if [ ! -e "$OC_DB_DATABASE" ] ; then
        touch "$OC_DB_DATABASE"
        chown "$USER_UID:$USER_UID" "$OC_DB_DATABASE" # Inherited $USER_UID from nginx/php
    fi
fi

# TODO check connection for other database types. Maybe one day...
# For now it doesn't matter. If it doesn't connect then we will soon find out


# Only replace the app key if we have one set by env.
if [ ! -z $OC_APP_KEY ] ; then
    sed -i "s#APP_KEY=.*#APP_KEY=$OC_APP_KEY#g" .env
fi

# Edit the rest of the .env configuration
sed -i "s#APP_DEBUG=.*#APP_DEBUG=$OC_APP_DEBUG#g" .env
sed -i "s#APP_URL=.*#APP_URL=$OC_APP_URL#g" .env
sed -i "s#DB_CONNECTION=.*#DB_CONNECTION=$OC_DB_CONNECTION#g" .env
sed -i "s#DB_HOST=.*#DB_HOST=$OC_DB_HOST#g" .env
sed -i "s#DB_PORT=.*#DB_PORT=$OC_DB_PORT#g" .env
sed -i "s#DB_DATABASE=.*#DB_DATABASE=$OC_DB_DATABASE#g" .env
sed -i "s#DB_USERNAME=.*#DB_USERNAME=$OC_DB_USERNAME#g" .env
sed -i "s#DB_PASSWORD=.*#DB_PASSWORD=$OC_DB_PASSWORD#g" .env
sed -i "s#REDIS_HOST=.*#REDIS_HOST=$OC_REDIS_HOST#g" .env
sed -i "s#REDIS_PASSWORD=.*#REDIS_PASSWORD=$OC_REDIS_PASSWORD#g" .env
sed -i "s#CACHE_DRIVER=.*#CACHE_DRIVER=$OC_CACHE_DRIVER#g" .env
sed -i "s#SESSION_DRIVER=.*#SESSION_DRIVER=$OC_SESSION_DRIVER#g" .env
sed -i "s#QUEUE_DRIVER=.*#QUEUE_DRIVER=$OC_QUEUE_DRIVER#g" .env
sed -i "s#MAIL_DRIVER=.*#MAIL_DRIVER=$OC_MAIL_DRIVER#g" .env
sed -i "s#MAIL_HOST=.*#MAIL_HOST=$OC_MAIL_HOST#g" .env
sed -i "s#MAIL_PORT=.*#MAIL_PORT=$OC_MAIL_PORT#g" .env
sed -i "s#MAIL_ENCRYPTION=.*#MAIL_ENCRYPTION=$OC_MAIL_ENCRYPTION#g" .env
sed -i "s#MAIL_USERNAME=.*#MAIL_USERNAME=$OC_MAIL_USERNAME#g" .env
sed -i "s#MAIL_PASSWORD=.*#MAIL_PASSWORD=$OC_MAIL_PASSWORD#g" .env
sed -i "s#ROUTES_CACHE=.*#ROUTES_CACHE=$OC_ROUTES_CACHE#g" .env
sed -i "s#ASSET_CACHE=.*#ASSET_CACHE=$OC_ASSET_CACHE#g" .env
sed -i "s#LINK_POLICY=.*#LINK_POLICY=$OC_LINK_POLICY#g" .env
sed -i "s#ENABLE_CSRF=.*#ENABLE_CSRF=$OC_ENABLE_CSRF#g" .env

# Delete the demo theme
if [ "$OC_FRESH_INSTALL" = 'true' ] && [ -d "themes/october/demo" ] ; then
    php artisan october:fresh
fi

# Bring up the database and install some plugins
if [ "$OC_DB_CONNECTION" != "none" ] ; then
    php artisan october:up
    # Always install drivers plugin
    php artisan plugin:install october.drivers

    # Install some useful plugins
    # TODO Install plugins as specified in .env
    php artisan plugin:install rainlab.pages
    php artisan plugin:install rainlab.sitemap
    php artisan plugin:install rainlab.blog
    php artisan plugin:install OFFLINE.gdpr
fi

exec "$@"
