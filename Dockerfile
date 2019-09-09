# Some parts borrowed from https://github.com/aspendigital/docker-octobercms

FROM dynamedia/docker-nginx-fpm:v1.17.3_7.3.9

LABEL maintainer="Rob Ballantyne <rob@dynamedia.uk>"

ENV OCTOBERCMS_TAG v1.0.458

### Install supplementary packages required by October CMS ###

RUN apt update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        curl \
        software-properties-common \
        gnupg2 && \
    curl -sL https://deb.nodesource.com/setup_11.x | bash - && \
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
    rm /etc/nginx/sites-enabled/conf.d/php.conf && \
    git clone https://github.com/octobercms/october.git -b $OCTOBERCMS_TAG --depth 1 app && \
    cd app && \
    composer install --no-interaction --prefer-dist --no-scripts && \
    composer clearcache && \
    git status && git reset --hard HEAD && \
    rm -rf .git && \
    mv themes/demo/ ./demotheme

COPY ./octobercms.conf /etc/nginx/sites-enabled/conf.d/octobercms.conf

COPY ./php_db_test.php /usr/local/bin/php_db_test.php

COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY ./user.crontab /user.crontab

COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR /var/www/app/

ENTRYPOINT ["entrypoint.sh"]

CMD ["/usr/bin/supervisord"]
