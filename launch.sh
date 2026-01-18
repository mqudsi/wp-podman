#!/bin/sh
echo "Launching WordPress on http://localhost:4242"
podman run --rm \
  --name wp-demo \
  -p 4242:80 \
  wp-unit
