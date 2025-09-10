#!/usr/bin/env bash
set -euo pipefail

# Crear carpeta simulando estructura de Let's Encrypt
mkdir -p ./letsencrypt/live/anprvision.duckdns.org

# Generar cert autofirmado en esa carpeta
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout ./letsencrypt/live/anprvision.duckdns.org/privkey.pem \
  -out ./letsencrypt/live/anprvision.duckdns.org/fullchain.pem \
  -subj "/CN=anprvision.duckdns.org"

echo "Self-signed creado en ./letsencrypt/live/anprvision.duckdns.org/"

