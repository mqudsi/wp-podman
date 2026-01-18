#!/bin/sh

echo "Launching WordPress on http://localhost:4242"

mkdir -p mysql
podman run --rm \
    --name wp-demo \
    -v ./mysql:/var/lib/mysql:Z \
    -p 4242:80 \
    wp-unit
