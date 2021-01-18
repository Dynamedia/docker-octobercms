# Some parts borrowed from https://github.com/aspendigital/docker-octobercms

# This will build from the 1.1 branch of October CMS

# Nginx 1.19.6 + PHP-FPM 7.4.14
FROM dynamedia/docker-nginx-fpm:v1.19.6_7.4.14

LABEL maintainer="Rob Ballantyne <rob@dynamedia.uk>"

### Install supplementary packages required by October CMS ###

RUN apt update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        curl \
        ssh \
        software-properties-common \
        gnupg2 && \
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
    rm -rf app && \
    rm /etc/nginx/sites-enabled/conf.d/php.conf

ARG COMPOSER_AUTH

RUN composer --no-cache create-project october/october app v1.1.* && \
    composer clear-cache && \
    cd app && \
    mv themes/demo/ ./demotheme

COPY ./octobercms.conf /etc/nginx/sites-enabled/conf.d/octobercms.conf

COPY ./php_db_test.php /usr/local/bin/php_db_test.php

COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY ./user.crontab /user.crontab

COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR /var/www/app/

ENTRYPOINT ["entrypoint.sh"]

CMD ["/usr/bin/supervisord"]
