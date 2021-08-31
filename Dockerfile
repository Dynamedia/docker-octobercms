# This will build from the v2 branch of October CMS

FROM dynamedia/docker-nginx-fpm:v1.20.0_8.0.x

LABEL maintainer="Rob Ballantyne <rob@dynamedia.uk>"

### Install supplementary packages required by October CMS ###

RUN apt update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        ca-certificates    \
        vim                \
        nano               \
        curl               \
        zlib1g             \
        libssl1.1          \
        libpcre3           \
        libxml2            \
        libyajl2           \
        sendmail-bin       \
        cron               \
        supervisor && \
    curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    apt update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        nodejs && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    ldconfig && \
    npm install yarn -g && \
    mv /usr/local/bin/entrypoint.sh /usr/local/bin/nginx-fpm-entrypoint.sh && \
    cd /var/www/ && \
    rm -rf app

ARG COMPOSER_AUTH
ARG OCTOBER_LICENSE

RUN composer --no-cache create-project october/october app v2.* && \
    composer clear-cache && \
    cd app && \
    php artisan project:set ${OCTOBER_LICENSE} && \
    php artisan october:build

# Sanitise the .env. **Do not ship this container with an app key**, it has to be generated on first run

RUN sed -i "s#DB_CONNECTION=.*#DB_CONNECTION=sqlite#g" /var/www/app/.env && \
    sed -i "s#APP_KEY=.*#APP_KEY=#g" /var/www/app/.env && \
    sed -i "s#DB_HOST=.*#DB_HOST=#g" /var/www/app/.env && \
    sed -i "s#DB_PORT=.*#DB_PORT=#g" /var/www/app/.env && \
    sed -i "s#DB_DATABASE=.*#DB_DATABASE='/var/www/app/storage/app/database.sqlite'#g" /var/www/app/.env && \
    sed -i "s#DB_USERNAME=.*#DB_USERNAME=#g" /var/www/app/.env && \
    sed -i "s#DB_PASSWORD=.*#DB_PASSWORD=#g" /var/www/app/.env && \
    # Create a more 'envable' configuration
    sed -i "s#'edgeUpdates'\s=>.*#'edgeUpdates' => env('EDGE_UPDATES', false),#g" /var/www/app/config/cms.php && \
    sed -i "s#'disableCoreUpdates'\s=>.*#'disableCoreUpdates' => env('DISABLE_CORE_UPDATES', false),#g" /var/www/app/config/cms.php && \
    sed -i "s#'backendForceSecure'\s=>.*#'backendForceSecure' => env('BACKEND_FORCE_SECURE', null),#g" /var/www/app/config/cms.php && \
    sed -i "s#'backendUri'\s=>.*#'backendUri' => env('BACKEND_URI', 'backend'),#g" /var/www/app/config/cms.php && \
    sed -i "s#'activeTheme'\s=>.*#'activeTheme' => env('ACTIVE_THEME', 'demo'),#g" /var/www/app/config/cms.php && \
    sed -i "s#'enableSafeMode'\s=>.*#'enableSafeMode' => env('ENABLE_SAFE_MODE', null),#g" /var/www/app/config/cms.php && \
    sed -i "s#'forceBytecodeInvalidation'\s=>.*#'forceBytecodeInvalidation' => env('FORCE_BYTECODE_INVALIDATION', true),#g" /var/www/app/config/cms.php && \
    sed -i "s#'convertLineEndings'\s=>.*#'convertLineEndings' => env('CONVERT_LINE_ENDINGS', false),#g" /var/www/app/config/cms.php && \
    sed -i "s#'name'\s=>.*#'name' => env('APP_NAME', 'October CMS'),#g" /var/www/app/config/app.php && \
    sed -i "s#'timezone'\s=>.*#'timezone' => env('APP_TIMEZONE', 'UTC'),#g" /var/www/app/config/app.php && \
    sed -i "s#'locale'\s=>.*#'locale' => env('APP_LOCALE', 'en'),#g" /var/www/app/config/app.php && \
    sed -i "s#'fallback_locale'\s=>.*#'fallback_locale' => env('APP_FALLBACK_LOCALE', 'en'),#g" /var/www/app/config/app.php && \
    sed -i "s#'cipher'\s=>.*#'cipher' => env('APP_CIPHER', 'AES-256-CBC'),#g" /var/www/app/config/app.php && \
    sed -i "s#'log'\s=>.*#'log' => env('APP_LOG', 'single'),#g" /var/www/app/config/app.php && \
    sed -i "s#'disableRequestCache'\s=>.*#'disableRequestCache' => env('DISABLE_REQUEST_CACHE', false),#g" /var/www/app/config/cache.php && \
    sed -i "s#'default'\s=>.*#'default' => env('BROADCASTER_DRIVER', 'pusher'),#g" /var/www/app/config/broadcasting.php && \
    sed -i "s#'default'\s=>.*#'default' => env('APP_ENVIRONMENT', 'development'),#g" /var/www/app/config/environment.php && \
    sed -i "s#'lifetime'\s=>.*#'lifetime' => env('SESSION_LIFETIME', 120),#g" /var/www/app/config/session.php && \
    sed -i "s#'expire_on_close'\s=>.*#'expire_on_close' => env('SESSION_EXPIRE_ON_CLOSE', false),#g" /var/www/app/config/session.php && \
    sed -i "s#'encrypt'\s=>.*#'encrypt' => env('SESSION_ENCRYPT', false),#g" /var/www/app/config/session.php && \
    sed -i "s#'cookie'\s=>.*#'cookie' => env('SESSION_COOKIE', 'october_session'),#g" /var/www/app/config/session.php && \
    echo "EDGE_UPDATES=false" >> /var/www/app/.env && \
    echo "DISABLE_CORE_UPDATES=true" >> /var/www/app/.env && \
    echo "BACKEND_FORCE_SECURE=null" >> /var/www/app/.env && \
    echo "ENABLE_SAFE_MODE=null" >> /var/www/app/.env && \
    echo "FORCE_BYTECODE_INVALIDATION=true" >> /var/www/app/.env && \
    echo "CONVERT_LINE_ENDINGS=false" >> /var/www/app/.env && \
    echo "APP_NAME=\"October CMS\"" >> /var/www/app/.env && \
    echo "APP_TIMEZONE=UTC" >> /var/www/app/.env && \
    echo "APP_LOCALE=en" >> /var/www/app/.env && \
    echo "APP_FALLBACK_LOCALE=en" >> /var/www/app/.env && \
    echo "APP_CIPHER=AES-256-CBC" >> /var/www/app/.env && \
    echo "APP_LOG=single" >> /var/www/app/.env && \
    echo "DISABLE_REQUEST_CACHE=false" >> /var/www/app/.env && \
    echo "BROADCASTER_DRIVER=pusher" >> /var/www/app/.env && \
    echo "APP_ENVIRONMENT=development" >> /var/www/app/.env && \
    echo "SESSION_LIFETIME=120" >> /var/www/app/.env && \
    echo "SESSION_EXPIRE_ON_CLOSE=false" >> /var/www/app/.env && \
    echo "SESSION_ENCRYPT=false" >> /var/www/app/.env && \
    echo "SESSION_COOKIE=october_session" >> /var/www/app/.env && \
    echo "ACTIVE_THEME=demo" >> /var/www/app/.env && \
    mv /var/www/app/.env /var/www/app/.env-original && \
    # Archive the config because its the only (I think) thing we don't want to clobber. This will be extracted with -k (no overwrite)
    tar -C /var/www/app -zcvf /var/www/app/config.tar.gz config && \
    rm -rf /var/www/app/config && \
    # Archive the original, default app for later extraction over local mount
    # Yes, use docker volumes instead for production but this is unhelpful during development
    tar -C /var/www/ -zcvf /var/www/app.tar.gz app

# Want to ship a container with changes to core, plugins, themes and storage baked in?
# Delete last line above and uncomment this (make sure you do have a fully populated app directory!)
#COPY ./.data/app /tmp/app
#RUN tar -C /tmp/ -zcvf /var/www/app.tar.gz app && \
#    rm -rf /tmp/app


# These are the files and directories we mount via docker-compose.yml, but they get copied into the image when it's built
COPY ./.config/php/default/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./.config/php/default/php.ini /usr/local/etc/php/php.ini

COPY ./.config/nginx/default/nginx.conf /etc/nginx/nginx.conf
COPY ./.config/nginx/default/sites-enabled /etc/nginx/sites-enabled

COPY ./.config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./.config/user.crontab /user.crontab

COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR /var/www/app/

ENTRYPOINT ["entrypoint.sh"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
