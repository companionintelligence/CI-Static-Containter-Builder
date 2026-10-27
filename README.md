<h1 align="center">CI Static Container Builder</h1>

<p align="center"><strong>A system for packaging any static web application into a self-contained Docker image that serves the site performantly over HTTPS.</strong></p>

<p align="center"><a href="https://hub.ci.computer">Website</a> · <a href="#quick-start">Get started</a> · <a href="https://docs.ci.computer/docs/reference/open-source-systems">Systems map</a></p>


Two complementary approaches are provided so you can choose the right trade-off for your workload:

| | nginx approach | WASM (Spin) approach |
|---|---|---|
| **Image size** | ~70 MB (Debian-based nginx) | ~300 MB (Spin runtime) / <10 MB (scratch) |
| **HTTPS** | ✅ Built-in | Via reverse proxy |
| **Startup** | ~100 ms | ~10–50 ms |
| **HTTP/2** | ✅ | ✅ (via proxy) |
| **SPA routing** | ✅ | ✅ |
| **Special runtime** | None | Containerd + Spin shim (scratch only) |

---

## Table of Contents

1. [Quick start](#quick-start)
2. [nginx HTTPS approach (recommended)](#nginx-https-approach)
3. [WebAssembly approach (Spin)](#webassembly-approach-spin)
4. [Environment variables & SSL certificates](#environment-variables--ssl-certificates)
5. [Docker Compose](#docker-compose)
6. [Build helper script](#build-helper-script)
7. [Project structure](#project-structure)
8. [Performance features](#performance-features)
9. [Security features](#security-features)

---

## Quick start

### Use the published image (no build required)

A pre-built multi-arch (amd64 + arm64) image is published publicly to GHCR on every push to `main`:

```bash
docker pull ghcr.io/companionintelligence/ci-static-containter-builder:latest

# Runs the baked-in default landing page over HTTP→HTTPS
docker run --rm -p 80:80 -p 443:443 \
  ghcr.io/companionintelligence/ci-static-containter-builder:latest
```

To serve **your own site** with the published image, layer your files on top:

```dockerfile
FROM ghcr.io/companionintelligence/ci-static-containter-builder:latest
COPY ./dist /usr/share/nginx/html
```

### Build from source

```bash
# Clone the repo
git clone https://github.com/companionintelligence/ci-static-containter-builder.git
cd ci-static-containter-builder

# Build a container from the included example site (nginx + HTTPS)
docker build \
  --build-arg STATIC_FILES_PATH=./example/public \
  -t my-site:latest .

# Run it – browse to https://localhost (accept the self-signed cert)
docker run --rm -p 80:80 -p 443:443 my-site:latest
```

> **Note:** `STATIC_FILES_PATH` is resolved by `COPY` inside the build, so it must
> point **inside the Docker build context** (the directory you pass to
> `docker build`). To package files that live elsewhere, copy them into the
> context first or use the `FROM ghcr.io/…` overlay pattern above.

---

## nginx HTTPS approach

### How it works

```
┌──────────────────────────────────────────────────────────┐
│  Docker image (nginx:1.27, Debian-based)                 │
│                                                          │
│  Port 80  ──▶ 301 redirect ──▶ Port 443                 │
│  Port 443 ──▶ nginx (HTTP/2, TLS 1.2/1.3)               │
│               ├── gzip compression                       │
│               ├── immutable cache headers                │
│               ├── security headers (HSTS, CSP, …)       │
│               └── /usr/share/nginx/html  (static files)  │
└──────────────────────────────────────────────────────────┘
```

### Build

```bash
docker build \
  --build-arg STATIC_FILES_PATH=./path/to/your/dist \
  -t my-site:latest \
  -f Dockerfile .
```

### Run

```bash
# Auto-generate a self-signed certificate for 'localhost'
docker run --rm -p 80:80 -p 443:443 my-site:latest

# Use a custom domain in the self-signed cert
docker run --rm -p 80:80 -p 443:443 \
  -e SSL_DOMAIN=myapp.example.com \
  my-site:latest

# Mount your own TLS certificate (e.g. from Let's Encrypt / cert-manager)
docker run --rm -p 80:80 -p 443:443 \
  -v /etc/letsencrypt/live/myapp.example.com/fullchain.pem:/etc/nginx/ssl/server.crt:ro \
  -v /etc/letsencrypt/live/myapp.example.com/privkey.pem:/etc/nginx/ssl/server.key:ro \
  my-site:latest
```

### Multi-stage build with your own app

```dockerfile
# Your app's Dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build          # output goes to /app/dist

FROM ghcr.io/companionintelligence/ci-static-containter-builder AS server
COPY --from=build /app/dist /usr/share/nginx/html
```

---

## WebAssembly approach (Spin)

The WASM approach uses [Fermyon Spin](https://www.fermyon.com/spin) to serve static files through a pre-compiled WebAssembly binary.  
Spin uses the [spin-fileserver](https://github.com/fermyon/spin-fileserver) component — a pure WASM module that implements HTTP file serving.

### Variant 1 – `spin-server` (default, no special runtime needed)

A lightweight Debian image with the Spin CLI baked in. Works with any Docker installation.

```bash
# Build
docker build \
  -f Dockerfile.wasm \
  --target spin-server \
  --build-arg STATIC_FILES_PATH=./path/to/your/dist \
  -t my-site-wasm:latest .

# Run (HTTP on port 3000)
docker run --rm -p 3000:3000 my-site-wasm:latest

# Browse to http://localhost:3000
```

### Variant 2 – `wasm-scratch` (OCI WASM scratch image)

A true OCI-compliant scratch image containing only WASM artifacts — **no Linux OS layer**.  
Requires Docker Desktop with **containerd** and the **Spin runtime shim** enabled.

> Enable in Docker Desktop → Settings → Features in development →
> "Use containerd for pulling and storing images" + "Enable Wasm"

```bash
# Build the scratch target
docker build \
  -f Dockerfile.wasm \
  --target wasm-scratch \
  --build-arg STATIC_FILES_PATH=./path/to/your/dist \
  -t my-site-wasm-scratch:latest .

# Run with the Spin containerd shim
docker run --rm -p 3000:3000 \
  --runtime=io.containerd.spin.v2 \
  --platform=wasi/wasm \
  my-site-wasm-scratch:latest
```

### Comparison: traditional vs. scratch WASM

| | Traditional Linux container | WASM scratch container |
|---|---|---|
| Size | 10 MB – 500 MB | < 5 MB |
| Startup | 300 ms – 2 s | < 50 ms |
| Security | Shared kernel | Sandboxed (no host access by default) |
| Portability | Architecture-specific | Cross-platform (run anywhere WASM runs) |
| Special runtime | None | containerd + Spin/WasmEdge shim |

### HTTPS with WASM

Because the WASM binary itself does not terminate TLS, add an nginx TLS proxy in front.  
See the commented `tls-proxy` service in [`docker-compose.wasm.yml`](docker-compose.wasm.yml).

```bash
# Start the WASM site + TLS proxy together
docker compose -f docker-compose.wasm.yml up --build
```

---

## Environment variables & SSL certificates

| Variable | Default | Description |
|---|---|---|
| `SSL_DOMAIN` | `localhost` | CN/SAN for the auto-generated self-signed certificate |
| `SSL_CERT` | — | PEM-encoded certificate (base64 or raw). Overrides auto-generation |
| `SSL_KEY` | — | PEM-encoded private key. Must be set together with `SSL_CERT` |

**Priority order (entrypoint):**

1. `SSL_CERT` + `SSL_KEY` environment variables
2. Files already present at `/etc/nginx/ssl/server.crt` + `server.key` (mounted volume)
3. Auto-generated self-signed certificate using `SSL_DOMAIN`

---

## Docker Compose

### nginx (HTTPS)

```bash
docker compose up --build          # starts nginx on ports 80 + 443
docker compose down
```

Edit [`docker-compose.yml`](docker-compose.yml) to change the `STATIC_FILES_PATH` build arg or mount your own certs.

### WASM (Spin)

```bash
docker compose -f docker-compose.wasm.yml up --build   # starts Spin on port 3000
docker compose -f docker-compose.wasm.yml down
```

---

## Build helper script

`scripts/build.sh` provides a convenient wrapper around the Docker commands above.

```bash
chmod +x scripts/build.sh

# Build nginx image from ./my-app/dist
./scripts/build.sh nginx build ./my-app/dist my-site:latest

# Run nginx container
./scripts/build.sh nginx run my-site:latest

# Build WASM image
./scripts/build.sh wasm build ./my-app/dist my-site-wasm:latest

# Run WASM container
./scripts/build.sh wasm run my-site-wasm:latest

# Docker Compose up/down
./scripts/build.sh nginx up
./scripts/build.sh nginx down
./scripts/build.sh wasm  up
./scripts/build.sh wasm  down
```

Set `WASM_TARGET=wasm-scratch` to build/run the OCI scratch variant.

---

## Project structure

```
ci-static-container-builder/
├── Dockerfile                   # nginx HTTPS static hosting
├── Dockerfile.wasm              # Spin/WASM static hosting (spin-server + wasm-scratch targets)
├── .dockerignore
├── docker-compose.yml           # nginx deployment
├── docker-compose.wasm.yml      # WASM deployment
├── nginx/
│   └── nginx.conf               # Performance-optimised nginx config
├── spin/
│   └── spin.toml                # Fermyon Spin manifest
├── scripts/
│   ├── docker-entrypoint.sh     # nginx container entrypoint (SSL cert handling)
│   └── build.sh                 # Build helper script
└── example/
    ├── public/                  # Example site for nginx container
    │   ├── index.html
    │   └── styles.css
    └── wasm-public/             # Example site for WASM container
        └── index.html
```

---

## Performance features

- **HTTP/2** – multiplexed streams for faster page loads
- **TLS 1.2 / 1.3 only** – fast handshakes, modern cipher suites
- **Gzip compression** – text assets compressed at level 6
- **Immutable cache headers** – versioned assets (JS/CSS/images) cached for 1 year
- **sendfile + tcp_nopush + tcp_nodelay** – kernel-level zero-copy transfers
- **WASM startup < 50 ms** – no kernel boot / init overhead (scratch image)
- **SPA router fallback** – `try_files $uri $uri/ /index.html`

---

## Security features

- `Strict-Transport-Security` with preload and `includeSubDomains`
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy` (camera, mic, geolocation denied)
- OCSP Stapling
- `server_tokens off` (no nginx version leak)
- Non-root nginx worker processes (official nginx image default)
- WASM sandbox: no host-kernel access by default

---

## References

- [Docker + WASM blog post](https://www.docker.com/blog/build-share-run-webassembly-apps-docker/)
- [Fermyon Spin](https://developer.fermyon.com/spin)
- [WasmEdge Developer Guide](https://wasmedge.org/docs/start/build-and-run/docker_wasm/)
- [spin-fileserver](https://github.com/fermyon/spin-fileserver)
- [nginx performance tuning](https://nginx.org/en/docs/http/ngx_http_gzip_module.html)

<!-- companion-hub-readme-deep-review -->

## Choose an image variant

| Variant | Runtime | Port | TLS behavior |
|---|---|---:|---|
| Nginx HTTPS | Standard Docker runtime | 80 and 443 | HTTP redirects to HTTPS; auto-generated certificate is self-signed unless you provide a certificate/key |
| `spin-server` | Standard Docker runtime with Spin | 3000 | Static-file server; no TLS configuration described by this image |
| `wasm-scratch` | containerd with Spin/WasmEdge shim and `wasi/wasm` platform | 3000 | WASM image for a compatible runtime |

`STATIC_FILES_PATH` selects the static site during the build. The Nginx variant accepts `SSL_CERT`, `SSL_KEY`, and `SSL_DOMAIN`; mount production certificates securely and terminate TLS at a trusted proxy when that better fits the deployment.

