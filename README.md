# October CMS based on PHP-FPM & Nginx

This repo will build October CMS v2 with your license key. Do not share the images.

Building octobercms with an empty data/app directory will give a clean install. Any subsequent build
will package your local changes.

Building mysql with a populated data/mysql will bundle your database. Local mounts will not
be clobbered at runtime (tar - k). This is useful for deploying/developing your app with a known 
state but which can be safely expanded upon.

Nginx, PHP FPM and October CMS.

Nginx and PHP are managed by supervisord. This will not suit all tastes, but October CMS is completely dependent
on PHP and requires a web server, so they are bundled. It is, however, relatively easy to rebuild the image 
without Nginx should you wish to separate them or use an alternative web server.

The parent image (Nginx & PHP-FPM )can be found [here](https://github.com/Dynamedia/docker-nginx-fpm). It is 
built using the two separate images detailed below.

PHP FPM includes the following additional modules:

- zip
- mysqli
- pdo_mysql
- soap
- opcache
- gd
- xdebug
- swoole

The parent image can be found [here](https://github.com/Dynamedia/docker-php-fpm).

Nginx includes the following dynamic modules:

- ModSecurity (includes the latest OWASP core ruleset) - Default disabled

- Headers More - Default enabled

- Geoip2 (Module support but database cannot be distributed - register, download and mount database to use) - Default disabled

- Google PageSpeed - Default disabled

- Google Brotli - Default enabled

Dynamic modules can be enabled or disabled as required.

The parent image can be found [here](https://github.com/Dynamedia/docker-nginx).

Environment variables supported by PHP and Nginx are as follows:

- USER_NAME
- USER_GROUP
- USER_UID
- USER_GID

These are used by the entrypoint script to ensure that file and directory permissions are set properly
and should match the details of the local host user.

Environment variables for October are documented within the .env-example file.

It is a deliberate choice to avoid over-use of environment variables. Most configuration should take place
within the provided files under ./config. This is because they can be mounted during development and the build
process will copy them to their respective locations within the image when it is rebuilt. See Dockerfile.

## Getting Started

You can use this standalone and access, by default, at localhost:80 but for best results in multi-site
environments use alongside [this](https://github.com/dynamedia/docker-reverse-proxy) reverse proxy, which supports 
setting the hostname and letsencrypt SSL.

The default setup uses sqlite, but of course you can use a database of your choice
along with redis etc.

Copy .env-example to .env

Set your COMPOSER_AUTH key with an appropriate Github token

Specify any themes and plugins you want to be installed. plugin:install and git repo (public & private) are supported

Check/edit your docker-compose.yml file

Edit config/october-env according to your preference. There is no need to set an app key as the startup process
will set one for you using the output of php artisan key:generate --show.

- Mount the local data/app directory at /var/www/app
- Mount the local config/october-env at /var/www/app/.env

The entire contents of the container's /vaw/www/app directory will be placed in the mounted directory and can be edited
locally. This can greatly simplify development and the directory can be made available to other containers.
In production you may wish to use a named volume.

docker-compose up

## Warnings

Please ensure that you read and understand the provided Dockerfile and entrypoint.sh before using.

Do not share images - You must build this image locally or use a private repository (OC License)

## Bugs

There might be bugs. Please let me know about them.
