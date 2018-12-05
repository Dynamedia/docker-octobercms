# Some parts borrowed from https://github.com/aspendigital/docker-octobercms

FROM dynamedia/docker-nginx-fpm

LABEL maintainer="Rob Ballantyne <rob@dynamedia.uk>"

ENV OCTOBERCMS_TAG v1.0.443

### Install supplementary packages required by October CMS ###

RUN apt update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        cron && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    ldconfig && \
    mv /usr/local/bin/entrypoint.sh /usr/local/bin/nginx-fpm-entrypoint.sh

WORKDIR /var/www/

RUN rm -rf app && \
    rm /etc/nginx/sites-enabled/conf.d/php.conf && \
    git clone https://github.com/octobercms/october.git -b $OCTOBERCMS_TAG --depth 1 app && \
    cd app && \
    composer install --no-interaction --prefer-dist --no-scripts && \
    composer clearcache && \
    git status && git reset --hard HEAD && \
    rm -rf .git

COPY ./octobercms.conf /etc/nginx/sites-enabled/conf.d/octobercms.conf

COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR /var/www/app/

ENTRYPOINT ["entrypoint.sh"]

CMD ["/usr/bin/supervisord"]
