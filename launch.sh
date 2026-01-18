#!/bin/sh

echo "Launching WordPress on http://localhost:4242"

mkdir -p mysql wp-content
podman run --rm \
    --name wp-demo \
    -v ./mysql:/var/lib/mysql:Z \
    -v ./wp-content:/var/www/wordpress/wp-content:Z \
    -p 4242:80 \
    wp-unit
