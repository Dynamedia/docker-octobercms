#!/bin/bash

(cd "$(dirname "${BASH_SOURCE[0]}")" && \
 /usr/local/bin/docker-compose down && \
 /usr/local/bin/docker-compose up -d)
