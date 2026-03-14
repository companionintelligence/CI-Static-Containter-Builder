# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# ci-static-container-builder  |  nginx HTTPS approach
#
# Packages any static-file directory into a self-contained Docker image that
# serves the site over HTTPS (HTTP/2) using nginx-alpine.
#
# Build arguments
#   STATIC_FILES_PATH  – host path to the pre-built static site (default: ./public)
#   SSL_DOMAIN         – CN used when auto-generating a self-signed cert (default: localhost)
#
# Runtime environment variables (all optional)
#   SSL_CERT     – PEM-encoded certificate (overrides auto-generation)
#   SSL_KEY      – PEM-encoded private key  (overrides auto-generation)
#   SSL_DOMAIN   – domain name for auto-generated self-signed cert
#
# Exposed ports:  80 (HTTP → HTTPS redirect)   443 (HTTPS)
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1: gather static files ─────────────────────────────────────────────
FROM alpine:3.19 AS static-files

ARG STATIC_FILES_PATH=./public
WORKDIR /site
COPY ${STATIC_FILES_PATH} .

# ── Stage 2: production nginx server ─────────────────────────────────────────
FROM nginx:1.27 AS server

# Replace default nginx config with our performance-optimised version
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Bake static files into the image
COPY --from=static-files /site /usr/share/nginx/html

# Pre-create the SSL directory (actual certs are written at runtime)
RUN mkdir -p /etc/nginx/ssl && chmod 700 /etc/nginx/ssl

# Entrypoint handles cert selection / generation before launching nginx
COPY scripts/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
