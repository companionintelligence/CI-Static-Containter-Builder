#!/usr/bin/env bash
# build.sh – helper script for building and running static-hosting containers
#
# Usage:
#   ./scripts/build.sh [nginx|wasm] [build|run|up|down] [options]
#
# Examples:
#   ./scripts/build.sh nginx build ./my-app/dist my-site:latest
#   ./scripts/build.sh nginx run  my-site:latest
#   ./scripts/build.sh wasm  build ./my-app/dist my-site-wasm:latest
#   ./scripts/build.sh wasm  run   my-site-wasm:latest
#   ./scripts/build.sh nginx up
#   ./scripts/build.sh nginx down

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODE="${1:-nginx}"       # nginx | wasm
COMMAND="${2:-build}"    # build | run | up | down
STATIC_PATH="${3:-}"     # path to static files (for build)
IMAGE_TAG="${4:-static-site:latest}"

print_usage() {
  grep '^# ' "$0" | sed 's/^# //'
  exit 1
}

# ── nginx approach ────────────────────────────────────────────────────────────
build_nginx() {
  local src="${1:-./public}"
  local tag="${2:-static-site:latest}"
  echo "▶ Building nginx HTTPS image from '${src}' → '${tag}'"
  docker build \
    --file "${REPO_ROOT}/Dockerfile" \
    --build-arg "STATIC_FILES_PATH=${src}" \
    --tag "${tag}" \
    "${REPO_ROOT}"
  echo "✔ Image built: ${tag}"
}

run_nginx() {
  local tag="${1:-static-site:latest}"
  local domain="${SSL_DOMAIN:-localhost}"
  echo "▶ Running nginx HTTPS container from '${tag}'"
  docker run --rm -it \
    -p 80:80 -p 443:443 \
    -e "SSL_DOMAIN=${domain}" \
    "${tag}"
}

# ── WASM approach ─────────────────────────────────────────────────────────────
build_wasm() {
  local src="${1:-./public}"
  local tag="${2:-static-site-wasm:latest}"
  local target="${WASM_TARGET:-spin-server}"
  echo "▶ Building WASM (${target}) image from '${src}' → '${tag}'"
  docker build \
    --file "${REPO_ROOT}/Dockerfile.wasm" \
    --target "${target}" \
    --build-arg "STATIC_FILES_PATH=${src}" \
    --tag "${tag}" \
    "${REPO_ROOT}"
  echo "✔ Image built: ${tag}"
}

run_wasm() {
  local tag="${1:-static-site-wasm:latest}"
  local target="${WASM_TARGET:-spin-server}"
  echo "▶ Running WASM container from '${tag}'"
  if [[ "${target}" == "wasm-scratch" ]]; then
    docker run --rm -it \
      -p 3000:3000 \
      --runtime=io.containerd.spin.v2 \
      --platform=wasi/wasm \
      "${tag}"
  else
    docker run --rm -it \
      -p 3000:3000 \
      "${tag}"
  fi
}

# ── compose helpers ───────────────────────────────────────────────────────────
compose_up() {
  local compose_file="${1:-${REPO_ROOT}/docker-compose.yml}"
  echo "▶ Starting services (${compose_file})"
  docker compose -f "${compose_file}" up --build -d
}

compose_down() {
  local compose_file="${1:-${REPO_ROOT}/docker-compose.yml}"
  echo "▶ Stopping services (${compose_file})"
  docker compose -f "${compose_file}" down
}

# ── dispatch ──────────────────────────────────────────────────────────────────
case "${MODE}" in
  nginx)
    case "${COMMAND}" in
      build) build_nginx "${STATIC_PATH}" "${IMAGE_TAG}" ;;
      run)   run_nginx   "${IMAGE_TAG}" ;;
      up)    compose_up  "${REPO_ROOT}/docker-compose.yml" ;;
      down)  compose_down "${REPO_ROOT}/docker-compose.yml" ;;
      *)     print_usage ;;
    esac
    ;;
  wasm)
    case "${COMMAND}" in
      build) build_wasm "${STATIC_PATH}" "${IMAGE_TAG}" ;;
      run)   run_wasm   "${IMAGE_TAG}" ;;
      up)    compose_up  "${REPO_ROOT}/docker-compose.wasm.yml" ;;
      down)  compose_down "${REPO_ROOT}/docker-compose.wasm.yml" ;;
      *)     print_usage ;;
    esac
    ;;
  *)
    print_usage
    ;;
esac
