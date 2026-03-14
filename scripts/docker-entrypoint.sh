#!/bin/sh
# docker-entrypoint.sh – SSL certificate selection / auto-generation
# Runs before nginx starts inside the container.
#
# Priority order for certificates:
#   1. SSL_CERT + SSL_KEY environment variables (PEM strings)
#   2. Files already present at /etc/nginx/ssl/server.crt + server.key
#      (mount your own cert via -v /path/to/certs:/etc/nginx/ssl)
#   3. Auto-generated self-signed certificate (development / internal use)
#      – domain controlled by SSL_DOMAIN env var (default: localhost)

set -e

SSL_DIR="/etc/nginx/ssl"
CERT_FILE="${SSL_DIR}/server.crt"
KEY_FILE="${SSL_DIR}/server.key"

if [ -n "${SSL_CERT}" ] && [ -n "${SSL_KEY}" ]; then
    echo "[entrypoint] Using SSL certificate and key from environment variables."
    printf '%s\n' "${SSL_CERT}" > "${CERT_FILE}"
    printf '%s\n' "${SSL_KEY}"  > "${KEY_FILE}"

elif [ -f "${CERT_FILE}" ] && [ -f "${KEY_FILE}" ]; then
    echo "[entrypoint] Using existing SSL certificate at ${CERT_FILE}."

else
    DOMAIN="${SSL_DOMAIN:-localhost}"
    echo "[entrypoint] Generating self-signed certificate for: ${DOMAIN}"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${KEY_FILE}" \
        -out    "${CERT_FILE}" \
        -subj   "/C=US/ST=State/L=City/O=Organization/CN=${DOMAIN}" \
        -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN},IP:127.0.0.1" \
        2>/dev/null
    echo "[entrypoint] Self-signed certificate generated (expires in 365 days)."
fi

chmod 600 "${KEY_FILE}"
chmod 644 "${CERT_FILE}"

exec "$@"
