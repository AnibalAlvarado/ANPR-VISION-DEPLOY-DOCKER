#!/usr/bin/env bash
# enable-and-issue-le-webroot.sh
# Activa la config de Let's Encrypt (webroot) en nginx-proxy y emite el certificado.
# Uso:
#   ./scripts/enable-and-issue-le-webroot.sh anprvision.duckdns.org tu-email@dominio.com
#
# Requisitos:
# - docker y docker compose instalados
# - Puertos 80/443 abiertos hacia este host
# - El dominio resolviendo a tu IP pública

set -euo pipefail

DOMAIN="${1:-anprvision.duckdns.org}"
EMAIL="${2:-admin@example.com}"
NGINX_CONF_DIR="nginx/proxy/conf.d"
LE_CONF="${NGINX_CONF_DIR}/default-le.conf"
ACTIVE_CONF="${NGINX_CONF_DIR}/default.conf"

echo "[INFO] Dominio: ${DOMAIN}"
echo "[INFO] Email   : ${EMAIL}"

# 1) Preparar directorios para ACME y certs
mkdir -p letsencrypt nginx/html

# 2) Activar config de LE (webroot) en nginx-proxy
if [ -f "${LE_CONF}" ]; then
  # Respaldar conf activa si existe
  if [ -f "${ACTIVE_CONF}" ]; then
    cp -f "${ACTIVE_CONF}" "${ACTIVE_CONF}.bak.$(date +%s)"
  fi
  # Copiar la conf LE como activa
  cp -f "${LE_CONF}" "${ACTIVE_CONF}"
  # Reemplazar dominio si fuese necesario
  if command -v sed >/dev/null 2>&1; then
    sed -i "s/anprvision\.duckdns\.org/${DOMAIN}/g" "${ACTIVE_CONF}" || true
    sed -i "s/example\.com/${DOMAIN}/g" "${ACTIVE_CONF}" || true
  fi
else
  echo "[ERROR] No existe ${LE_CONF}. ¿Estás en el modo two-engines correcto?"; exit 1
fi

# 3) Levantar/recargar nginx-proxy para que sirva el webroot
echo "[INFO] Levantando nginx-proxy con config LE..."
docker compose up -d --build nginx-proxy

# 4) (Opcional) Prueba rápida del webroot ACME
TEST_FILE="nginx/html/.well-known/acme-challenge/test-$(date +%s)"
mkdir -p "$(dirname "${TEST_FILE}")"
echo "OK-ACME" > "${TEST_FILE}"
echo "[INFO] Prueba webroot: http://${DOMAIN}/.well-known/acme-challenge/$(basename "${TEST_FILE}")"
if command -v curl >/dev/null 2>&1; then
  set +e
  curl -sSf "http://${DOMAIN}/.well-known/acme-challenge/$(basename "${TEST_FILE}")" | grep -q "OK-ACME"
  RC=$?
  set -e
  if [ $RC -ne 0 ]; then
    echo "[WARN] No se pudo verificar el webroot localmente. Asegúrate que 80 llegue desde internet."
  else
    echo "[OK] Webroot accesible."
  fi
else
  echo "[WARN] 'curl' no está en el host. Omitiendo prueba local del webroot."
fi

# 5) Emitir el certificado (webroot)
echo "[INFO] Emisión del certificado con Certbot (webroot)..."
docker run --rm \
  -v "$(pwd)/letsencrypt:/etc/letsencrypt" \
  -v "$(pwd)/nginx/html:/var/www/certbot" \
  certbot/certbot certonly --webroot \
    -w /var/www/certbot \
    -d "${DOMAIN}" \
    --agree-tos -m "${EMAIL}" --non-interactive

# 6) Recargar nginx-proxy (usará los certs emitidos en /etc/letsencrypt/live/...)
echo "[INFO] Recargando nginx-proxy con certificados recién emitidos..."
docker compose up -d --build nginx-proxy

# 7) Mostrar info del certificado
echo "[INFO] Info del cert remoto:"
if command -v openssl >/dev/null 2>&1; then
  echo | openssl s_client -connect "${DOMAIN}:443" -servername "${DOMAIN}" -showcerts 2>/dev/null | openssl x509 -noout -issuer -subject -dates || true
else
  echo "[WARN] 'openssl' no está en el host. Verifica con: curl -I https://${DOMAIN}/"
fi

echo "[DONE] Listo. Prueba: https://${DOMAIN}/  y  https://${DOMAIN}/api/health"
echo "[TIP] Renovación: ./scripts/renew-letsencrypt.sh"
