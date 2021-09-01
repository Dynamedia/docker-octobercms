#!/bin/bash

echo "extracting build time databases..."
# -k option will not clobber existing files, so its safe to restart with new data in a mount/volume
tar -k -zxf /var/lib/mysql-overlay.tar.gz -C /var/lib/ > /dev/null 2>&1

exec /usr/local/bin/docker-entrypoint.sh "$@"
