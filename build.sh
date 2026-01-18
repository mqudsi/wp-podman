#!/bin/sh
echo "Building Docker image 'wp-unit'..."
podman build -t wp-unit .
