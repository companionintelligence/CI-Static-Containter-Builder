# Architectural Design for Performant, Wasm-Powered Static Web Application Hosting within Docker Environments


## Introduction to Next-Generation Static Hosting Architectures

The paradigm of web application hosting has undergone continuous, iterative evolution, transitioning from bare-metal servers to virtual machines, and subsequently to containerized Linux environments. For the specific use case of serving static web applications—comprising pre-compiled HyperText Markup Language (HTML), Cascading Style Sheets (CSS), JavaScript, and media assets—traditional containerization strategies often introduce unnecessary systemic overhead. Conventional Linux containers bundle a complete userland operating system, complex networking utilities, and an array of system libraries simply to serve static files over a network.<sup>1</sup> This architectural mismatch results in inflated image sizes, extended deployment times, and expanded security attack surfaces that are disproportionate to the actual workload requirements.

The emergence of WebAssembly (Wasm) on the server side, facilitated by the WebAssembly System Interface (WASI), introduces a highly optimized, specialized alternative to traditional containerization. Wasm-powered containers function as specialized, Open Container Initiative (OCI)-compliant artifacts containing solely a compiled WebAssembly binary and essential execution metadata, intentionally omitting a full Linux operating system.<sup>1</sup> By entirely bypassing the Linux userland layer, these artifacts redefine the performance characteristics, security models, and cold-start latencies of cloud-native applications.

This comprehensive research report provides an exhaustive architectural blueprint for designing a high-performance system to publish and host static websites within Docker containers. The design specifically integrates Wasm-based static file servers with dynamic, automated HTTPS reverse proxying. Through a rigorous examination of historical web server architectures, modern component selection, containerization strategies, continuous integration pipelines, and empirical performance benchmarking, the subsequent analysis demonstrates how to construct a resilient, zero-configuration Transport Layer Security (TLS) infrastructure. This infrastructure explicitly leverages the sub-millisecond startup times and minimal cryptographic footprint of WebAssembly to deliver static content with unprecedented efficiency.<sup>3</sup>


## The Evolution of Web Server Architecture: From Process Models to Event Loops

To adequately contextualize the performance implications of the proposed architecture, it is necessary to examine the historical trajectory of web server design, specifically evaluating how different architectures handle concurrent connections and static file delivery.


## The Process-Driven Model

The Apache HTTP Server, released in 1995, established the foundational framework for modern web hosting. Its architecture is inherently highly modular and traditionally process-driven. Apache utilizes Multi-Processing Modules (MPMs) to define how it handles incoming network requests.<sup>5</sup> The legacy prefork MPM operates by spawning a distinct, separate operating system process for every single incoming connection. While this provided robust isolation—meaning a crash in one request would not terminate the entire server—it proved exceptionally heavy in terms of Random Access Memory (RAM) utilization.<sup>5</sup>

As web traffic scaled globally, this process-per-connection model encountered a hard mathematical limit known as the C10k problem, referring to the inability of traditional servers to handle 10,000 concurrent connections due to the exhaustion of system resources and the excessive overhead of context switching between thousands of parallel processes.<sup>7</sup> Although Apache later introduced the worker (thread-based) and event (non-blocking) MPMs to mitigate these bottlenecks, its fundamental architectural legacy remained tied to complex, heavy request handling.<sup>5</sup>


## The Asynchronous Event-Driven Model

Nginx emerged in 2004 as a direct, engineered response to the C10k problem. Instead of spawning new processes or threads for each incoming connection, Nginx was built from the ground up on an asynchronous, event-driven, non-blocking architecture.<sup>5</sup> A highly optimized master process manages a small, fixed number of worker processes—typically matched to the number of available CPU cores. Each worker process executes a continuous event loop, processing thousands of concurrent connections simultaneously without blocking on Input/Output (I/O) operations.<sup>5</sup>

For static file delivery, Nginx represents the industry zenith of raw performance. It efficiently delegates the heavy lifting to the operating system kernel by utilizing the sendfile system call. This allows the kernel to copy data directly from the disk cache to the network socket buffer, entirely bypassing the need to copy data into the web server's user-space application memory.<sup>8</sup> As a result, synthetic benchmarks repeatedly demonstrate Nginx serving thousands of static requests per second with negligible CPU and RAM consumption.<sup>5</sup>


## The Modern Cloud-Native Proxy Model

Despite Nginx's unparalleled raw static file throughput, its configuration syntax is statically defined, requiring manual editing of .conf files and external daemons (like Certbot) to manage modern security requirements such as automated TLS certificate rotation.<sup>12</sup> As infrastructure shifted toward ephemeral, containerized microservices managed by orchestration platforms like Docker Swarm and Kubernetes, the need arose for reverse proxies capable of dynamic service discovery.

Traefik and Caddy represent this modern paradigm. Traefik was designed explicitly for containerized environments, utilizing Docker labels to dynamically generate routing rules without configuration reloads.<sup>14</sup> However, its configuration syntax is often considered verbose and highly complex.<sup>15</sup>

Caddy, developed in Go, prioritizes extreme operational simplicity while maintaining robust performance via the Go runtime's lightweight goroutine scheduling model.<sup>12</sup> Its defining characteristic is automated, out-of-the-box HTTPS provisioning via the Automated Certificate Management Environment (ACME) protocol.<sup>13</sup> Through the caddy-docker-proxy integration, Caddy merges its automated TLS capabilities with Traefik-style dynamic Docker service discovery, creating an optimal, zero-friction ingress tier for modern architectures.<sup>15</sup>


<table>
  <tr>
   <td><strong>Web Server / Proxy</strong>
   </td>
   <td><strong>Architectural Model</strong>
   </td>
   <td><strong>Static File Performance</strong>
   </td>
   <td><strong>Automated HTTPS</strong>
   </td>
   <td><strong>Dynamic Docker Discovery</strong>
   </td>
  </tr>
  <tr>
   <td><strong>Apache HTTP</strong>
   </td>
   <td>Process/Thread MPMs
   </td>
   <td>Moderate
   </td>
   <td>Requires External Tools
   </td>
   <td>Requires External Tools
   </td>
  </tr>
  <tr>
   <td><strong>Nginx</strong>
   </td>
   <td>Asynchronous Event-Driven
   </td>
   <td>Maximum / Excellent
   </td>
   <td>Requires External Tools
   </td>
   <td>Requires Commercial/External
   </td>
  </tr>
  <tr>
   <td><strong>Traefik</strong>
   </td>
   <td>Go Goroutines
   </td>
   <td>High / Proxy-focused
   </td>
   <td>Native
   </td>
   <td>Native (Labels)
   </td>
  </tr>
  <tr>
   <td><strong>Caddy</strong>
   </td>
   <td>Go Goroutines
   </td>
   <td>High / Excellent
   </td>
   <td>Native (Default)
   </td>
   <td>Native (via caddy-docker-proxy)
   </td>
  </tr>
</table>



## The WebAssembly Paradigm Shift: From Browser Sandbox to Cloud Compute

To design a highly performant static hosting system using WebAssembly, one must understand the fundamental divergence between traditional Linux containerization and WASI-enabled execution environments. WebAssembly was initially ratified as a binary instruction format designed as a secure compilation target for high-level languages (such as C, C++, and Rust), executing primarily within the sandboxed environment of a web browser to deliver near-native execution speeds for client-side applications.<sup>21</sup>


## The WebAssembly System Interface (WASI)

The true utility of WebAssembly in cloud-native infrastructure was unlocked by the development of the WebAssembly System Interface (WASI). WASI provides a modular, standardized Application Programming Interface (API) that grants Wasm modules controlled access to operating system capabilities, including the filesystem, clocks, random number generators, and network sockets.<sup>22</sup>

Crucially, WASI implements a capability-based security model. Unlike a traditional Linux container executing under a root or service user account—which implicitly inherits broad filesystem and network permissions unless strictly locked down by AppArmor or SELinux policies—a Wasm module possesses zero access to the host system by default.<sup>22</sup> Every specific file directory and network port must be explicitly passed into the Wasm runtime environment at execution time. This capability-based model ensures that even if a static file server contains an exploitable buffer overflow or path traversal vulnerability, the blast radius is strictly confined to the pre-allocated memory linear space and explicitly pre-opened directories.<sup>22</sup>


## Docker, Containerd, and OCI Artifact Standardization

Historically, deploying WebAssembly workloads required bespoke deployment pipelines, forcing organizations to adopt new toolchains that fractured their existing Docker-centric infrastructure.<sup>26</sup> This operational friction was resolved by a strategic collaboration between Docker and the Cloud Native Computing Foundation (CNCF) Wasm Working Group, which established specifications for packaging Wasm modules as standard Open Container Initiative (OCI) artifacts.<sup>1</sup>

This standardization dictates that a WebAssembly application can be packaged, pushed, pulled, and tagged within registries like Docker Hub or GitHub Container Registry (GHCR) exactly like a standard Linux container image.<sup>1</sup> The Docker Engine architecture accommodates this by extending its underlying containerd runtime. Rather than universally relying on runc to spawn Linux namespaces and cgroups, containerd utilizes specialized shims (e.g., containerd-shim-wasmedge-v1 or containerd-shim-spin-v1) that intercept the execution flow and instantiate a WebAssembly runtime engine instead.<sup>3</sup>


## Architectural Comparison: Linux Containers versus Wasm Modules

The systemic transition from deploying a static web server within an Alpine Linux container to deploying it within a Wasm container yields profound architectural advantages across four primary metrics.


<table>
  <tr>
   <td><strong>Feature Metric</strong>
   </td>
   <td><strong>Traditional Linux Container (e.g., Nginx Alpine)</strong>
   </td>
   <td><strong>Wasm-Powered Container (e.g., Fermyon Spin)</strong>
   </td>
  </tr>
  <tr>
   <td><strong>Artifact Size</strong>
   </td>
   <td>10MB – 500MB+ (Includes OS userland libraries)
   </td>
   <td>&lt;1MB – 5MB (Compiled binary and assets only)
   </td>
  </tr>
  <tr>
   <td><strong>Startup Latency</strong>
   </td>
   <td>300ms – 2s (Kernel boot, namespace allocation, init)
   </td>
   <td>&lt;10ms – 50ms (Near-instant bytecode execution)
   </td>
  </tr>
  <tr>
   <td><strong>Security Posture</strong>
   </td>
   <td>Shared kernel, large userland attack surface
   </td>
   <td>Isolated sandbox, no host access by default
   </td>
  </tr>
  <tr>
   <td><strong>Portability</strong>
   </td>
   <td>OS/Architecture specific (e.g., linux/amd64)
   </td>
   <td>Cross-platform, universal execution (wasi/wasm)
   </td>
  </tr>
</table>


Data synthesized from foundational architectural analyses and benchmarking.<sup>1</sup>



1. **Artifact Size and Distribution:** A standard Linux container hosting Nginx typically ranges from 15MB to 50MB, containing an entire suite of GNU or Musl utilities, package managers (apk or apt), and core system libraries.<sup>1</sup> A Wasm container deployed via a scratch image contains exclusively the compiled WebAssembly bytecode and the static HTML/CSS assets, frequently resulting in a total image size under 3MB.<sup>1</sup>
2. **Cold Start Latency:** Container orchestrators managing Linux environments must invoke the host kernel to allocate discrete namespaces, configure control groups (cgroups), and initialize the container's entrypoint process.<sup>4</sup> This process inherently introduces hundreds of milliseconds of cold-start latency. Wasm modules executed via containerd shims bypass the Linux kernel process isolation mechanisms entirely, achieving full execution state in under 10 to 50 milliseconds.<sup>3</sup> In specialized environments, Wasm cold starts have been benchmarked at 0.5 milliseconds.<sup>4</sup>
3. **Security and Vulnerability Management:** Because traditional containers share the host kernel, any vulnerability within the container's expansive userland (such as an embedded curl binary or a flawed OpenSSL library) presents a viable vector for exploitation and potential container escape.<sup>29</sup> By utilizing pure Wasm execution within a scratch image, there is no shell environment, no package manager, and no underlying Linux utilities available to malicious actors, effectively neutralizing vast categories of Common Vulnerabilities and Exposures (CVEs).<sup>22</sup>
4. **Hardware Architecture Agnosticism:** Standard Docker images must be cross-compiled for specific CPU architectures (e.g., linux/amd64 for Intel/AMD servers or linux/arm64 for Apple Silicon and AWS Graviton).<sup>27</sup> Wasm artifacts operate at a higher level of abstraction. A single wasi/wasm image functions universally; the local Wasm runtime handles the Just-In-Time (JIT) or Ahead-Of-Time (AOT) compilation to the host's native instruction set at the exact moment of execution.<sup>1</sup>


## Ingress Tier Architecture: Designing the Dynamic Reverse Proxy

For the proposed architecture, the ingress tier serves as the public-facing boundary of the application. It is exclusively responsible for terminating incoming SSL/TLS connections, routing incoming HTTP requests to the appropriate backend Wasm containers, applying network-level compression (GZip/Brotli), and dynamically adapting to the changing topology of the internal Docker network.


## Selection and Implementation of Caddy via Docker Socket Discovery

While Nginx excels at raw static file delivery, utilizing it as an ingress proxy in a highly dynamic, Docker-orchestrated environment necessitates managing static nginx.conf files. Whenever a new container is deployed or an internal IP address changes, the Nginx configuration must be rewritten and the daemon reloaded, typically managed by third-party utilities like jwilder/nginx-proxy or manual templating engines.<sup>12</sup>

Caddy, combined with the caddy-docker-proxy plugin, circumvents this operational overhead entirely. The proxy container is deployed with a read-only bind mount to the host machine's Docker Engine API socket (/var/run/docker.sock).<sup>15</sup> By maintaining a persistent, real-time connection to the Docker Engine's event stream, the Caddy plugin actively monitors the lifecycle events of all containers deployed on the host.<sup>20</sup>

When a new backend Wasm container is instantiated, the proxy inspects the container's metadata for specific labels prefixed with caddy.<sup>15</sup> Upon detecting these designated labels, the plugin parses the routing instructions, dynamically generates an in-memory Caddyfile configuration, and seamlessly triggers a graceful reload of the Caddy web server.<sup>20</sup> This zero-downtime reload ensures that active client connections are maintained while new routing paths are seamlessly instantiated.<sup>18</sup>


## Automated Certificate Management Environment (ACME) Integration

The most substantial architectural advantage of Caddy is its native, default implementation of the ACME protocol for automated TLS certificate provisioning.<sup>12</sup> Traditional architectures require configuring Certbot cron jobs to solve Let's Encrypt HTTP-01 or DNS-01 challenges, manage the private keys, and signal the web server to reload upon certificate renewal.<sup>13</sup>

When a container is deployed with a label such as caddy: application.example.com, Caddy automatically intercepts the configuration, generates a cryptographic private key, communicates with Let's Encrypt or ZeroSSL to solve the cryptographic challenge, and securely stores the resulting TLS certificate within its persistent data volume.<sup>18</sup> Furthermore, Caddy intelligently handles OCSP stapling, HTTP/2 and HTTP/3 protocol upgrades, and automatic redirection of unencrypted Port 80 HTTP traffic to secure Port 443 HTTPS traffic without any manual configuration.<sup>13</sup>


## Establishing Ingress Network Isolation

Security best practices mandate that the reverse proxy must be the sole component exposing ports to the public internet.<sup>32</sup> The backend Wasm containers must remain entirely isolated from external ingress.

To achieve this, the architecture defines a dedicated, internal Docker bridge network (e.g., caddy_ingress_net). Both the Caddy proxy container and the backend Wasm containers are explicitly attached to this isolated network layer.<sup>32</sup> The Wasm containers expose no ports to the host machine (-p directives are omitted). When the caddy-docker-proxy detects a backend service, it utilizes Docker's internal Domain Name System (DNS) resolution to route the decrypted traffic directly to the backend container's internal, virtualized IP address.<sup>20</sup> This topology guarantees that unencrypted HTTP traffic flowing between the proxy and the Wasm application tier remains strictly encapsulated within the host's virtualized network boundaries.


## Application Tier Engineering: Developing the Wasm Static File Server

The application tier is responsible for reading the static HTML, CSS, and JavaScript assets from disk and transmitting them over the internal network to the ingress proxy. To utilize WebAssembly, these static files must be packaged into a Wasm container alongside a web server binary compiled to the wasm32-wasi target.

While there are multiple methodologies for constructing a Wasm static server, the architecture must balance extreme performance with operational simplicity.


## Evaluation of Wasm Server Implementations



1. **WasmEdge with Rust or Node.js:** The WasmEdge runtime provides a high-performance execution environment for custom applications. A developer could write an HTTP server in Rust using the hyper or tokio crates, compile it to wasm32-wasip1, and map a local directory of static files into the container at runtime.<sup>1</sup> Alternatively, WasmEdge supports running a full Node.js environment compiled to Wasm, executing an express.js static server.<sup>1</sup> While highly versatile, this approach requires maintaining custom source code and managing manual directory mounts, increasing the operational burden.<sup>1</sup>
2. **Static Web Server (SWS):** SWS is a production-ready, highly optimized asynchronous web server explicitly engineered for serving static assets. Built in Rust and powered by the Tokio async runtime, it supports HTTP/1 and HTTP/2 and provides advanced features like on-demand GZip/Brotli/Zstandard compression, CORS handling, and basic authentication.<sup>35</sup> SWS provides first-class Docker support, including sub-5MB scratch images, and is fully compatible with WebAssembly compilation via Wasmer.<sup>35</sup>
3. **Fermyon Spin Framework:** Spin is an open-source framework developed specifically for authoring event-driven WebAssembly microservices.<sup>3</sup> Spin abstracts away the complexities of low-level WASI socket programming. For static hosting, Spin provides a pre-built static-fileserver component template. During the build process, Spin parses a manifest file, identifies the specified local directory of static assets, and bundles them into the deployment artifact.<sup>36</sup>

For the proposed architecture, **Fermyon Spin** represents the optimal solution. Because Spin is deeply integrated with Docker Desktop's experimental containerd shims (specifically io.containerd.spin.v1), it offers the most frictionless, declarative path for bundling directories of static files into pure Wasm containers without requiring the developer to write or maintain custom Rust or Go web server code.<sup>27</sup>


## Constructing the Spin Application Manifest

The architecture leverages the Fermyon Spin static-fileserver template to map a local directory of assets into a virtualized filesystem within the Wasm binary. The configuration is declared entirely within a spin.toml manifest file.<sup>36</sup>

A standard, production-ready spin.toml configuration is structured as follows:


    Ini, TOML

spin_manifest_version = "1" \
name = "performant-static-site" \
version = "1.0.0" \
trigger = { type = "http", base = "/" } \
 \
[[component]] \
id = "frontend-assets" \
source = { url = "https://github.com/fermyon/spin-fileserver/releases/download/v0.1.0/spin_static_fs.wasm", digest = "sha256:96c76d9af86420b39eb6cd7be5550e3cb5d4cc4de572ce0fd1f6a29471536cb4" } \
files = [{ source = "public_html/", destination = "/" }] \
 \
[component.trigger] \
route = "/..." \


*Architectural Analysis of the Manifest:* The configuration above relies on component composition and declarative logic.<sup>39</sup> The source directive instructs the Spin framework to download a highly optimized, pre-compiled WebAssembly binary (spin_static_fs.wasm) published by Fermyon, verifying its cryptographic integrity via the SHA-256 digest.<sup>39</sup>

The critical element is the files array. This directive instructs the Spin build engine to ingest the local public_html/ directory containing the static website assets.<sup>36</sup> During the packaging phase, these static files are firmly embedded into the execution context, creating a cohesive, self-contained deployment unit. When a request matches the /... wildcard route, the Spin HTTP trigger invokes the Wasm binary, which efficiently streams the requested static file directly back to the client proxy.<sup>25</sup>


## Containerization Mechanics: Engineering the Scratch Image

Once the Spin application manifest is configured and the static assets are prepared, the artifact must be packaged into a Docker image. The paramount objective is to construct the most minimalist, secure image physically possible. This is executed by targeting Docker's scratch base image.<sup>3</sup>


## The Anatomy and Constraints of a Scratch Container

The scratch image in the Docker ecosystem is a unique, reserved construct. It is an entirely empty filesystem placeholder; it contains zero megabytes of data, no shell environment (like bash or sh), no standard C libraries (glibc or musl), and no package management utilities (apt or apk).<sup>29</sup>

When engineering a traditional Linux application (e.g., a Golang or Rust binary) for a scratch container, developers must ensure the binary is statically linked. Standard dynamic linking relies on the host operating system providing shared libraries (like libc) at runtime. Because a scratch container possesses no operating system files, a dynamically linked binary will instantly crash upon execution, citing missing dependencies.<sup>29</sup>

WebAssembly intrinsically bypasses this limitation. Wasm modules are universally self-contained bytecode formats.<sup>42</sup> They contain no native system calls and rely entirely on the host's WebAssembly runtime (e.g., Wasmtime, WasmEdge) to mediate interactions with the underlying hardware via WASI.<sup>22</sup> Consequently, copying a Wasm module and its associated configuration into a completely empty scratch container yields a perfectly functional, ultra-minimalist OCI image.<sup>1</sup>


## The WebAssembly Dockerfile Construction

The Dockerfile required to package the Spin application is exceptionally succinct, focusing purely on transferring the requisite files into the empty artifact layer.


    Dockerfile

# syntax=docker/dockerfile:1 \
 \
# Utilize the empty scratch image \
FROM scratch \
 \
# Transfer the Spin framework manifest \
COPY spin.toml /spin.toml \
 \
# Transfer the pre-compiled WebAssembly static server binary \
COPY spin_static_fs.wasm /spin_static_fs.wasm \
 \
# Transfer the directory containing the static website assets \
COPY public_html/ /public_html/ \


*Note on Execution Directives:* Traditional Dockerfiles typically conclude with an ENTRYPOINT or CMD directive pointing to a Linux executable (e.g., CMD ["nginx", "-g", "daemon off;"]).<sup>41</sup> However, when utilizing Docker's Wasm integration via containerd, the execution logic is delegated entirely to the containerd shim specified at runtime. Therefore, an explicit ENTRYPOINT within the Dockerfile is completely unnecessary; the Docker Engine inherently understands how to parse the artifact when commanded to execute via the Spin runtime shim.<sup>27</sup>


## Orchestration and Networking Topology via Docker Compose

The synthesis of the Caddy ingress proxy and the Wasm application tier is masterfully orchestrated via Docker Compose. This declarative Infrastructure-as-Code (IaC) file defines the strict networking boundaries, assigns the specialized Wasm runtimes, and utilizes Docker metadata labels to configure the automatic HTTPS routing.


## Architectural Definition of the Docker Compose Topology

The following YAML configuration represents the complete, production-ready system architecture:


    YAML

version: '3.8' \
 \
# Define the isolated internal network \
networks: \
  caddy_ingress_net: \
    name: caddy_ingress_net \
    driver: bridge \
 \
services: \
  # The Ingress Reverse Proxy Tier \
  proxy_controller: \
    image: lucaslorentz/caddy-docker-proxy:alpine \
    container_name: caddy_ingress \
    ports: \
      - "80:80"     # Required for ACME HTTP-01 challenges and redirects \
      - "443:443"   # Required for encrypted HTTPS traffic \
    environment: \
      # Instruct the proxy to exclusively monitor containers on this network \
      - CADDY_INGRESS_NETWORKS=caddy_ingress_net \
    networks: \
      - caddy_ingress_net \
    volumes: \
      # Bind mount the Docker socket in read-only mode for service discovery \
      - /var/run/docker.sock:/var/run/docker.sock:ro \
      # Persistent volume for cryptographic keys and certificates \
      - caddy_certificates:/data \
    restart: unless-stopped \
 \
  # The Application Tier (Wasm Static Hosting Container) \
  static_website: \
    image: my-registry/wasm-static-webapp:latest \
    container_name: wasm_frontend \
    # Explicitly instruct Docker to execute using the Fermyon Spin shim \
    runtime: io.containerd.spin.v1 \
    platform: wasi/wasm \
    networks: \
      - caddy_ingress_net \
    labels: \
      # Instruct Caddy to acquire a Let's Encrypt certificate for this domain \
      caddy: secure-site.example.com \
      # Dynamically route incoming traffic to the internal Spin HTTP listener \
      caddy.reverse_proxy: "{{upstreams 80}}" \
    restart: unless-stopped \
 \
# Declare persistent storage volumes \
volumes: \
  caddy_certificates: \



## Strategic Analysis of the Orchestration Directives

This orchestration file establishes a highly resilient, autonomous architecture through several carefully engineered mechanisms:



1. **Cryptographic Persistence (caddy_certificates volume):** ACME providers like Let's Encrypt enforce strict rate limits regarding how frequently a domain can request certificate issuance.<sup>18</sup> By mounting the caddy_certificates persistent volume to the /data directory of the proxy container, Caddy securely stores the negotiated private keys and signed certificates.<sup>15</sup> If the proxy container crashes or is deliberately updated, it will load the existing, valid certificates directly from disk upon initialization, completely avoiding rate-limit exhaustion and ensuring immediate HTTPS availability.<sup>18</sup>
2. **Runtime Delegation (runtime: io.containerd.spin.v1):** This parameter is the foundational linchpin of the WebAssembly application tier. Standard Docker execution relies on the runc runtime to spawn isolated Linux processes. By explicitly overriding the runtime via the Compose file, the Docker daemon intercepts the standard flow and passes the container execution context to the Fermyon Spin containerd shim.<sup>27</sup> This shim reads the wasi/wasm binary architecture, instantiates the embedded WebAssembly engine, parses the spin.toml manifest, and commences listening for incoming HTTP requests on the default internal port 80.<sup>3</sup>
3. **Zero-Configuration Routing and Load Balancing:** The labels array attached to the static_website container acts as dynamic configuration blocks for the Caddy ingress controller.<sup>45</sup> The caddy: secure-site.example.com label acts as a trigger, instructing the proxy to immediately initiate an ACME challenge to provision an SSL certificate for that specific domain.<sup>18</sup> Concurrently, the caddy.reverse_proxy: "{{upstreams 80}}" label commands Caddy to dynamically discover the internal virtual IP address of the Wasm container and establish a reverse proxy tunnel to it.<sup>20</sup> If an administrator scales the static_website service to multiple replicas to handle increased traffic volume, Caddy automatically detects the new container IP addresses and initiates round-robin load balancing across all available Wasm instances without requiring any manual intervention.<sup>47</sup>


## Continuous Integration and Deployment (CI/CD) Automation

To maintain engineering velocity and ensure absolute artifact integrity, the cross-compilation of the static assets and the Spin configuration into a deployable Wasm Docker image must be heavily automated. Modern CI/CD systems, such as GitHub Actions or GitLab CI, possess native integrations for Docker Buildx, facilitating the creation of multi-platform OCI artifacts and seamlessly pushing them to container registries like Docker Hub or the GitHub Container Registry (GHCR).<sup>21</sup>


## Orchestrating the Wasm Build and Push Pipeline

Building wasi/wasm targeted images within a standard Linux CI runner requires specialized tooling, primarily to explicitly instruct the Docker daemon to output a WebAssembly platform architecture rather than defaulting to the host system's native CPU architecture (e.g., linux/amd64).<sup>28</sup>

The automated pipeline execution follows four distinct phases: Codebase Checkout, Emulation/Toolchain Initialization, Docker Build/Push Execution, and Metadata Tagging.



1. **Toolchain Initialization:** The CI runner must configure the Docker environment to support non-native platform builds. This is reliably achieved using the docker/setup-qemu-action (which provides hardware emulation support) and the docker/setup-buildx-action (which initializes the advanced BuildKit engine necessary for multi-platform compilation).<sup>30</sup>
2. **Registry Authentication:** The pipeline securely authenticates against the target OCI registry (such as Docker Hub or GHCR) utilizing encrypted repository secrets, securing the artifact push phase of the workflow.<sup>30</sup>
3. **Compilation and Architecture Targeting:** Utilizing the docker/build-push-action, the pipeline executes the minimalist Dockerfile. The absolutely critical parameter in this step is platforms: wasi/wasm.<sup>28</sup> This explicit declaration guarantees that the resulting OCI image manifest is tagged with the correct architecture metadata. Failure to specify this results in the image being tagged as a standard Linux binary, which causes catastrophic runtime architecture mismatch errors when the production server's containerd shim attempts to execute it.<sup>28</sup>


## GitHub Actions Workflow Implementation

The following complete YAML implementation details a production-grade CI pipeline tailored for the WebAssembly static hosting architecture:


    YAML

name: Build and Publish Wasm Static Site \
 \
on: \
  push: \
    branches: \
      - main \
  workflow_dispatch: \
 \
env: \
  REGISTRY: ghcr.io \
  IMAGE_NAME: ${{ github.repository }} \
 \
jobs: \
  build-and-push-wasm-artifact: \
    runs-on: ubuntu-latest \
    permissions: \
      contents: read \
      packages: write \
 \
    steps: \
      - name: Checkout Source Code \
        uses: actions/checkout@v4 \
 \
      - name: Initialize QEMU Hardware Emulation \
        uses: docker/setup-qemu-action@v3 \
 \
      - name: Initialize Docker Buildx (BuildKit) \
        uses: docker/setup-buildx-action@v3 \
        with: \
          # Enable containerd snapshotter for advanced OCI support \
          driver-opts: image=moby/buildkit:latest \
 \
      - name: Authenticate to Container Registry \
        uses: docker/login-action@v3 \
        with: \
          registry: ${{ env.REGISTRY }} \
          username: ${{ github.actor }} \
          password: ${{ secrets.GITHUB_TOKEN }} \
 \
      - name: Extract Docker Metadata (Tags and Labels) \
        id: meta \
        uses: docker/metadata-action@v5 \
        with: \
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }} \
          tags: | \
            type=sha,format=short \
            type=raw,value=latest,enable={{is_default_branch}} \
 \
      - name: Build and Push WebAssembly OCI Artifact \
        uses: docker/build-push-action@v5 \
        with: \
          context:. \
          file:./Dockerfile \
          push: true \
          # Explicitly target the WebAssembly architecture for the shim \
          platforms: wasi/wasm \
          tags: ${{ steps.meta.outputs.tags }} \
          labels: ${{ steps.meta.outputs.labels }} \


*Architectural Implications of the Pipeline:* By pushing the compiled artifact to an OCI-compliant registry, the WebAssembly module is treated identically to a Linux container. This standardization means the target production server requires absolutely no custom Wasm-specific tooling to fetch and update the application. A standard docker compose pull && docker compose up -d workflow will seamlessly download the updated Wasm container, replace the running instance, and instantly trigger Caddy to hot-reload the routing rules as the new container instance comes online.<sup>20</sup>


## Empirical Performance Analysis and Benchmarking

A rigorous architectural design must justify its component selections through empirical performance analysis. The decision to front Wasm-based static file servers with a Go-based Caddy proxy introduces highly specific theoretical and practical performance characteristics, particularly when compared to a traditional monolithic Nginx deployment.


## Throughput and Latency Profiles

Nginx is unequivocally engineered for the maximum theoretical delivery of static files. Operating via an asynchronous, event-driven architecture, it utilizes kernel-level optimizations like sendfile to completely bypass user-space memory buffers, instructing the operating system to transfer file contents directly from the disk cache to the network interface card.<sup>5</sup> In raw high-concurrency synthetic benchmarks—such as utilizing tools like wrk to bombard the server with thousands of concurrent requests for a 100KB static asset—a properly tuned Nginx instance will typically yield maximum theoretical throughput, often easily saturating a gigabit network link.<sup>6</sup>

Caddy, while also highly performant and fully capable of saturating network links, relies on the Go runtime's goroutine multiplexing model rather than a pure C-based event loop.<sup>17</sup> Synthetic benchmarks indicate that Nginx may maintain an edge in sub-millisecond tail latencies under extreme stress testing.<sup>11</sup> However, in real-world deployments—where network latency, TLS 1.3 cryptographic handshakes, and browser Document Object Model (DOM) rendering times are the dominant bottleneck factors—the difference between Caddy and Nginx is computationally imperceptible to the end-user.<sup>52</sup> The marginal trade-off in peak raw synthetic throughput is overwhelmingly offset by Caddy's massive reduction in operational complexity, automated SSL lifecycle management, and native dynamic label routing capabilities.<sup>6</sup>


## Cold Start and Autoscaling Dynamics

The integration of WebAssembly in the application tier dramatically alters the system's performance profile regarding horizontal scaling. Traditional Linux containers exhibit notably high cold-start latencies. Initiating a new Nginx container to handle sudden traffic spikes requires allocating network namespaces, configuring control groups, and executing the container's entrypoint initialization sequence, often taking hundreds of milliseconds to multiple seconds before the application is ready to bind to a port and accept TCP traffic.<sup>4</sup>

WebAssembly runtime engines, such as those utilized by Spin and WasmEdge, bypass the operating system's process isolation overhead entirely. Wasm modules exhibit true sub-millisecond cold start times.<sup>3</sup> The analysis indicates that deploying Spin containers allows the architecture to scale from zero to thousands of instances nearly instantaneously.<sup>4</sup> When integrated with orchestration systems or dynamic Docker environments, this microsecond-level initiation ensures that incoming HTTP requests routed by the Caddy proxy are not blocked waiting for a backend instance to initialize.


## Resource Utilization and Memory Footprint Density

Resource consumption is a critical metric for cloud deployment density and cost efficiency. A standard idle Nginx container will consume between 5MB and 15MB of RAM, scaling rapidly upward as multiple worker processes spawn to handle connections.<sup>7</sup>

In stark contrast, a bare WebAssembly binary operating within a scratch container imposes virtually zero overhead beyond the Wasm runtime executing it.<sup>1</sup> By eliminating the Linux userland entirely, memory allocations are restricted strictly to the WebAssembly engine's linear memory model and the active HTTP request buffers.<sup>1</sup> This extreme efficiency allows a single host machine to densely pack thousands of isolated Wasm static file servers concurrently, far exceeding the container density achievable with traditional Linux environments.<sup>4</sup>


<table>
  <tr>
   <td><strong>Performance Metric</strong>
   </td>
   <td><strong>Nginx Reverse Proxy + Linux Static Server</strong>
   </td>
   <td><strong>Caddy Reverse Proxy + Wasm Static Server</strong>
   </td>
  </tr>
  <tr>
   <td><strong>Synthetic Throughput</strong>
   </td>
   <td>Exceptional (Kernel sendfile optimized)
   </td>
   <td>High (Goroutine & Wasm execution bounds)
   </td>
  </tr>
  <tr>
   <td><strong>Cold Start Latency</strong>
   </td>
   <td>High (500ms - 2000ms)
   </td>
   <td>Microsecond (&lt;10ms - 50ms)
   </td>
  </tr>
  <tr>
   <td><strong>Base Memory Footprint</strong>
   </td>
   <td>Moderate (~15MB - 50MB)
   </td>
   <td>Minimal (~2MB - 5MB)
   </td>
  </tr>
  <tr>
   <td><strong>Real-world TTFB</strong>
   </td>
   <td>Excellent
   </td>
   <td>Excellent (Imperceptible difference)
   </td>
  </tr>
</table>


TTFB: Time To First Byte. Benchmarks indicate that while Nginx wins in raw synthetic C-level benchmarks, the Wasm architecture provides vastly superior scaling mechanics and memory density.<sup>4</sup>


## Security Posture and Vulnerability Management

Beyond performance characteristics, the transition to a WebAssembly-based static hosting architecture fundamentally transforms the system's security posture.


## Eradicating Userland Vulnerabilities

Traditional Linux containers, even lightweight variants like Alpine Linux, inherently possess an attack surface. They contain package managers, shell interpreters (/bin/sh), networking utilities (curl, wget), and underlying C standard libraries (musl or glibc).<sup>29</sup> If an attacker successfully exploits a vulnerability within the web application (such as a remote code execution flaw or a sophisticated directory traversal), they can leverage these existing internal tools to download malicious payloads, establish reverse shells, or attempt container escape to compromise the host kernel.<sup>22</sup> This reality necessitates continuous CVE scanning and regular base image patching.

By utilizing WebAssembly deployed within a Docker scratch image, the attack surface is mathematically minimized. The scratch image contains absolutely zero utilities. There is no shell to invoke, no curl to download payloads, and no filesystem beyond the specific compiled static assets.<sup>29</sup> Even in the event of a catastrophic logic flaw within the static server code, the attacker is trapped within an empty void, incapable of interacting with the host system or executing secondary payloads.<sup>29</sup>


## Capability-Based Execution Sandboxing

Furthermore, the WASI specification enforces a default-deny, capability-based security model. A Wasm module is fundamentally restricted from performing arbitrary system calls.<sup>22</sup> It cannot open network sockets to unexpected destinations or read files outside of the explicitly pre-opened directories provided by the containerd shim at execution time.<sup>22</sup> This sandboxing provides a level of isolation that is vastly superior to traditional process-level separation, rendering entire categories of system-level exploits structurally impossible within the Wasm architecture.<sup>4</sup>


## Operationalizing the Architecture: Deployment Best Practices

Deploying this highly specialized architecture to a production environment demands strict adherence to specific operational protocols to ensure stability, seamless maintainability, and optimal performance.


## Docker Daemon Configuration and Containerd Integration

Before attempting to execute Wasm containers, the target Docker host must be explicitly configured to utilize the containerd image store and support WebAssembly execution shims. Historically, Docker utilized its own proprietary graph drivers (such as overlay2) for image storage, which were incompatible with certain advanced OCI artifact specifications.<sup>3</sup>

Systems administrators must actively enable the containerd snapshotter. In Docker Desktop environments, this involves navigating to the development settings and explicitly enabling "Use containerd for pulling and storing images" alongside the "Enable Wasm" feature toggle.<sup>3</sup> For headless Linux server deployments, the /etc/docker/daemon.json configuration file must be systematically updated to specify the containerd backend features, and the appropriate WebAssembly shims (e.g., containerd-shim-spin-v1 or containerd-shim-wasmedge-v1) must be downloaded and installed in the host's executable PATH.<sup>3</sup>


## Local Development Parity and Cross-Platform Consistency

A core, foundational tenet of modern DevOps methodologies is maintaining strict environmental parity between local development workstations and remote production servers. Because the CI/CD pipeline cross-compiles the static assets into a distinct WebAssembly artifact, developers must be able to seamlessly replicate this execution process locally without enduring complex, brittle toolchain installations.<sup>1</sup>

By explicitly leveraging Docker's native capability to execute WebAssembly via containerd shims, developers can execute the exact same docker-compose.yml configuration on their local workstations (whether operating macOS, Windows, or Linux) that is utilized in the production environment.<sup>26</sup> Because WebAssembly is inherently, mathematically cross-platform, the identical bytecode binary compiled on the developer's machine will execute flawlessly on the production server. This fundamental characteristic completely eradicates the pervasive "it works on my machine" anti-pattern historically associated with architecture-specific compiled C or Go binaries.<sup>1</sup>

Furthermore, for local testing scenarios where public DNS resolution is unavailable, Caddy seamlessly falls back to establishing local trust architectures. When accessed via the localhost domain, Caddy automatically generates and explicitly trusts a local Certificate Authority (CA), providing a secure, fully encrypted HTTPS experience during local development that accurately and faithfully mirrors the production TLS termination process without throwing browser certificate warnings.<sup>18</sup>


## Centralized Caching and Compression Strategies

To optimize network bandwidth utilization and drastically decrease client-side browser load times, both caching headers and payload compression must be aggressively implemented across the architecture. While modern Wasm static file servers (such as SWS or Spin implementations) often possess built-in compression capabilities, it is architecturally advantageous to offload this processing overhead to the ingress proxy.<sup>35</sup>

Caddy can be seamlessly configured via its dynamic labels to apply GZip and Zstandard (zstd) compression algorithms to all outgoing HTTP responses. Because Caddy operates directly at the public network boundary, configuring compression at this specific tier centralizes the CPU load on the Go-based proxy. This strategic delegation ensures that the internal Wasm backend containers expend compute cycles exclusively on retrieving and rapidly transmitting the raw file bytes from their virtualized filesystems, maximizing overall systemic throughput.<sup>18</sup>


## Conclusion

The convergence of WebAssembly and Docker signifies a fundamental, paradigm-altering shift in how cloud-native infrastructure is architected, provisioned, and scaled. By purposefully transitioning away from monolithic, OS-laden Linux containers toward ultra-lightweight, strictly sandboxed Wasm artifacts, systems engineers can achieve unprecedented levels of security, operational deployment density, and startup velocity.

This comprehensive architectural blueprint demonstrates that securely serving static web applications no longer requires reliance on heavy container orchestration or highly complex, manual configuration management. The integration of Caddy—acting as a dynamic, HTTPS-automated reverse proxy driven entirely by declarative Docker labels—with Fermyon Spin's Wasm-compiled static file servers yields a deployment topology that is highly performant, remarkably secure, and operationally frictionless. The ingress tier elegantly and invisibly manages the extreme complexities of SSL/TLS termination, automated renewals, and internal service discovery, while the application tier leverages the inherent strengths of WebAssembly to serve compiled static assets with sub-millisecond initiation times and nearly undetectable resource overhead.

Coupled with a robust GitHub Actions CI/CD automation pipeline capable of building and pushing multi-platform wasi/wasm images directly to standard OCI registries, this architectural design achieves continuous, seamless, and perfectly reproducible delivery. The resulting infrastructure presents a highly scalable, mathematically secure, and thoroughly modern approach to static application hosting, successfully and efficiently mapping the stringent, high-availability performance requirements of the modern web onto the vast, emerging capabilities of next-generation container runtimes.


#### Works cited



1. Docker + WASM | WasmEdge Developer Guides, accessed March 13, 2026, [https://wasmedge.org/docs/start/build-and-run/docker_wasm/](https://wasmedge.org/docs/start/build-and-run/docker_wasm/)
2. Docker + WASM | WasmEdge Developer Guides, accessed March 13, 2026, [https://wasmedge.org/docs/start/build-and-run/docker_wasm](https://wasmedge.org/docs/start/build-and-run/docker_wasm)
3. How to Use Docker with Spin Framework for Wasm - OneUptime, accessed March 13, 2026, [https://oneuptime.com/blog/post/2026-02-08-how-to-use-docker-with-spin-framework-for-wasm/view](https://oneuptime.com/blog/post/2026-02-08-how-to-use-docker-with-spin-framework-for-wasm/view)
4. Running Serverless Wasm Functions on the Edge with k3s and SpinKube - Fermyon, accessed March 13, 2026, [https://www.fermyon.com/blog/spinkube-k3s](https://www.fermyon.com/blog/spinkube-k3s)
5. Nginx vs Apache: Which Web Server Is Faster in 2025? - Blog | WeHaveServers.com, accessed March 13, 2026, [https://wehaveservers.com/blog/linux-sysadmin/nginx-vs-apache-which-web-server-is-faster-in-2025/](https://wehaveservers.com/blog/linux-sysadmin/nginx-vs-apache-which-web-server-is-faster-in-2025/)
6. Apache vs Nginx: Performance and Use Cases - CubePath Docs, accessed March 13, 2026, [https://cubepath.com/en/docs/comparison-guide/apache-vs-nginx-performance-and-use-cases](https://cubepath.com/en/docs/comparison-guide/apache-vs-nginx-performance-and-use-cases)
7. Apache vs Nginx: The Ultimate Web Server Showdown in 2025 - Codezion Softwares, accessed March 13, 2026, [https://www.codezion.com/blog/apache-vs-nginx/](https://www.codezion.com/blog/apache-vs-nginx/)
8. Does Nginx actually have better performance (RAM/CPU) than apache2 using it as reverse proxy/web-server? - Reddit, accessed March 13, 2026, [https://www.reddit.com/r/selfhosted/comments/1djt8nb/does_nginx_actually_have_better_performance/](https://www.reddit.com/r/selfhosted/comments/1djt8nb/does_nginx_actually_have_better_performance/)
9. Benchmarking nginx vs caddy vs uvicorn for serving static files, accessed March 13, 2026, [https://wersdoerfer.de/blogs/ephes_blog/benchmark-nginx-caddy-uvicorn/](https://wersdoerfer.de/blogs/ephes_blog/benchmark-nginx-caddy-uvicorn/)
10. node.js itself or nginx frontend for serving static files? - Stack Overflow, accessed March 13, 2026, [https://stackoverflow.com/questions/9967887/node-js-itself-or-nginx-frontend-for-serving-static-files](https://stackoverflow.com/questions/9967887/node-js-itself-or-nginx-frontend-for-serving-static-files)
11. NGINX vs Apache: Choosing the Best Web Server for Your Needs in 2025 | Vulnaly, accessed March 13, 2026, [https://vulnaly.com/blog/nginx-vs-apache-choosing-the-best-web-server-for-your-needs-in-2025](https://vulnaly.com/blog/nginx-vs-apache-choosing-the-best-web-server-for-your-needs-in-2025)
12. Nginx vs. Caddy vs. Traefik for Hop3 - Abilian Innovation Lab, accessed March 13, 2026, [https://lab.abilian.com/Projects/Hop3/Nginx%20vs.%20Caddy%20vs.%20Traefik%20for%20Hop3/](https://lab.abilian.com/Projects/Hop3/Nginx%20vs.%20Caddy%20vs.%20Traefik%20for%20Hop3/)
13. Why Choose Caddy Server instead Nginx? | by Salih İbrahimbaş - Medium, accessed March 13, 2026, [https://salihdev.medium.com/why-choose-caddy-server-over-nginx-e49b01c631a1](https://salihdev.medium.com/why-choose-caddy-server-over-nginx-e49b01c631a1)
14. caddy-docker-proxy vs traefik vs nginx-proxy-manager : r/selfhosted - Reddit, accessed March 13, 2026, [https://www.reddit.com/r/selfhosted/comments/uw50ua/caddydockerproxy_vs_traefik_vs_nginxproxymanager/](https://www.reddit.com/r/selfhosted/comments/uw50ua/caddydockerproxy_vs_traefik_vs_nginxproxymanager/)
15. Caddy Docker Proxy, Like Traefik But Better? - DEV Community, accessed March 13, 2026, [https://dev.to/jhot/caddy-docker-proxy-like-traefik-but-better-565l](https://dev.to/jhot/caddy-docker-proxy-like-traefik-but-better-565l)
16. Caddy vs Traefik, Which Do You Use and Why? : r/selfhosted - Reddit, accessed March 13, 2026, [https://www.reddit.com/r/selfhosted/comments/1jdy2gn/caddy_vs_traefik_which_do_you_use_and_why/](https://www.reddit.com/r/selfhosted/comments/1jdy2gn/caddy_vs_traefik_which_do_you_use_and_why/)
17. 35 Million Hot Dogs: Benchmarking Caddy vs. Nginx - Tyblog, accessed March 13, 2026, [https://blog.tjll.net/reverse-proxy-hot-dog-eating-contest-caddy-vs-nginx/](https://blog.tjll.net/reverse-proxy-hot-dog-eating-contest-caddy-vs-nginx/)
18. How to Use Docker with Caddy for Automatic HTTPS - OneUptime, accessed March 13, 2026, [https://oneuptime.com/blog/post/2026-01-16-docker-caddy-automatic-https/view](https://oneuptime.com/blog/post/2026-01-16-docker-caddy-automatic-https/view)
19. Caddy vs. Nginx: A Comparative Dive Into Modern Web Servers - Oreate AI Blog, accessed March 13, 2026, [https://www.oreateai.com/blog/caddy-vs-nginx-a-comparative-dive-into-modern-web-servers/ff724abb98f909e327ccd932a0f8fced](https://www.oreateai.com/blog/caddy-vs-nginx-a-comparative-dive-into-modern-web-servers/ff724abb98f909e327ccd932a0f8fced)
20. lucaslorentz/caddy-docker-proxy - GitHub, accessed March 13, 2026, [https://github.com/lucaslorentz/caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy)
21. Distributing WebAssembly components using OCI registries | Microsoft Open Source Blog, accessed March 13, 2026, [https://opensource.microsoft.com/blog/2024/09/25/distributing-webassembly-components-using-oci-registries/](https://opensource.microsoft.com/blog/2024/09/25/distributing-webassembly-components-using-oci-registries/)
22. Wasm vs. Docker: Performant, Secure, and Versatile Containers, accessed March 13, 2026, [https://www.docker.com/blog/wasm-vs-docker/](https://www.docker.com/blog/wasm-vs-docker/)
23. I was understanding WASM all wrong! | by Yuji Isobe - Medium, accessed March 13, 2026, [https://medium.com/@yujiisobe/i-was-understanding-wasm-all-wrong-e4bcab8d077c](https://medium.com/@yujiisobe/i-was-understanding-wasm-all-wrong-e4bcab8d077c)
24. WasmEdge, a high-performance WebAssembly runtime with Rust first APIs and Features (Wasm on server side) - Reddit, accessed March 13, 2026, [https://www.reddit.com/r/rust/comments/z8r7rq/wasmedge_a_highperformance_webassembly_runtime/](https://www.reddit.com/r/rust/comments/z8r7rq/wasmedge_a_highperformance_webassembly_runtime/)
25. Building Serverless Apps with Spin and HTMX - Fermyon, accessed March 13, 2026, [https://www.fermyon.com/blog/building-with-spin-htmx](https://www.fermyon.com/blog/building-with-spin-htmx)
26. Build, Share, and Run WebAssembly Apps Using Docker, accessed March 13, 2026, [https://www.docker.com/blog/build-share-run-webassembly-apps-docker/](https://www.docker.com/blog/build-share-run-webassembly-apps-docker/)
27. Docker Desktop and Spin for Serverless WebAssembly Apps - Fermyon, accessed March 13, 2026, [https://www.fermyon.com/blog/spin-in-docker](https://www.fermyon.com/blog/spin-in-docker)
28. Wasm workloads - Docker Docs, accessed March 13, 2026, [https://docs.docker.com/desktop/features/wasm/](https://docs.docker.com/desktop/features/wasm/)
29. What is Scratch base image ?How to explore Docker Scratch base Image in file system?, accessed March 13, 2026, [https://www.reddit.com/r/docker/comments/1hv5aze/what_is_scratch_base_image_how_to_explore_docker/](https://www.reddit.com/r/docker/comments/1hv5aze/what_is_scratch_base_image_how_to_explore_docker/)
30. Multi-platform image with GitHub Actions - Docker Docs, accessed March 13, 2026, [https://docs.docker.com/build/ci/github-actions/multi-platform/](https://docs.docker.com/build/ci/github-actions/multi-platform/)
31. WasmEdge - Hacker News, accessed March 13, 2026, [https://news.ycombinator.com/item?id=33792322](https://news.ycombinator.com/item?id=33792322)
32. Access container ONLY through reverse proxy - General - Docker Community Forums, accessed March 13, 2026, [https://forums.docker.com/t/access-container-only-through-reverse-proxy/114661](https://forums.docker.com/t/access-container-only-through-reverse-proxy/114661)
33. Setting up caddy-docker-proxy for basic-auth SSO, accessed March 13, 2026, [https://caddy.community/t/setting-up-caddy-docker-proxy-for-basic-auth-sso/15655](https://caddy.community/t/setting-up-caddy-docker-proxy-for-basic-auth-sso/15655)
34. Example: SSR | WasmEdge Developer Guides, accessed March 13, 2026, [https://wasmedge.org/docs/develop/javascript/ssr/](https://wasmedge.org/docs/develop/javascript/ssr/)
35. Static Web Server - GitHub, accessed March 13, 2026, [https://github.com/static-web-server/static-web-server](https://github.com/static-web-server/static-web-server)
36. Spin Application Structure - Fermyon, accessed March 13, 2026, [https://www.fermyon.com/blog/spin-application-structure](https://www.fermyon.com/blog/spin-application-structure)
37. Component Templates with Spin - Fermyon, accessed March 13, 2026, [https://www.fermyon.com/blog/component-reuse](https://www.fermyon.com/blog/component-reuse)
38. Serving Static Content via WebAssembly - Fermyon, accessed March 13, 2026, [https://www.fermyon.com/blog/serving-static-content-via-webassembly](https://www.fermyon.com/blog/serving-static-content-via-webassembly)
39. Integrating Spin with Static Site Generators - Fermyon, accessed March 13, 2026, [https://www.fermyon.com/blog/2023-06-07-integrating-with-ssgs](https://www.fermyon.com/blog/2023-06-07-integrating-with-ssgs)
40. spinframework/spin-fileserver: A static file server implemented as a Spin component, accessed March 13, 2026, [https://github.com/spinframework/spin-fileserver](https://github.com/spinframework/spin-fileserver)
41. The smallest Docker image to serve static websites - Florin Lipan, accessed March 13, 2026, [https://lipanski.com/posts/smallest-docker-image-static-website](https://lipanski.com/posts/smallest-docker-image-static-website)
42. Building a Standalone Rust Binary for a Scratch Docker Container, accessed March 13, 2026, [https://bxbrenden.github.io/](https://bxbrenden.github.io/)
43. WebAssembly: Docker without containers! - Wasm Labs, accessed March 13, 2026, [https://wasmlabs.dev/articles/docker-without-containers/](https://wasmlabs.dev/articles/docker-without-containers/)
44. Struggling with Caddy-Docker-Proxy | by Ayo Newton | Medium, accessed March 13, 2026, [https://medium.com/@fish_underlings/struggling-with-caddy-docker-proxy-2936f9256a79](https://medium.com/@fish_underlings/struggling-with-caddy-docker-proxy-2936f9256a79)
45. Caddy with Docker Labels: Easy config for wildcard certs and Authelia - Gist - GitHub, accessed March 13, 2026, [https://gist.github.com/omltcat/241ef622070ca0580f2876a7cfa7de67](https://gist.github.com/omltcat/241ef622070ca0580f2876a7cfa7de67)
46. Am I missing something or is Caddy really as easy as it looks? - Reddit, accessed March 13, 2026, [https://www.reddit.com/r/unRAID/comments/1f1zd66/am_i_missing_something_or_is_caddy_really_as_easy/](https://www.reddit.com/r/unRAID/comments/1f1zd66/am_i_missing_something_or_is_caddy_really_as_easy/)
47. Caddy caddy-docker-proxy to handle load balancing with reverse proxy> - Help, accessed March 13, 2026, [https://caddy.community/t/caddy-caddy-docker-proxy-to-handle-load-balancing-with-reverse-proxy/16640](https://caddy.community/t/caddy-caddy-docker-proxy-to-handle-load-balancing-with-reverse-proxy/16640)
48. Boost Your CI/CD Pipeline: Automate Docker With GitHub Actions - The New Stack, accessed March 13, 2026, [https://thenewstack.io/boost-your-ci-cd-pipeline-automate-docker-with-github-actions/](https://thenewstack.io/boost-your-ci-cd-pipeline-automate-docker-with-github-actions/)
49. How to Build Portable Microservices with Docker and Wasm - OneUptime, accessed March 13, 2026, [https://oneuptime.com/blog/post/2026-02-08-how-to-build-portable-microservices-with-docker-and-wasm/view](https://oneuptime.com/blog/post/2026-02-08-how-to-build-portable-microservices-with-docker-and-wasm/view)
50. GitHub Action to build and push Docker images with Buildx, accessed March 13, 2026, [https://github.com/docker/build-push-action](https://github.com/docker/build-push-action)
51. Building and Pushing Docker Image to Docker Hub using GitHub Actions | by Shen Lu, accessed March 13, 2026, [https://medium.com/@shenlu89/building-and-pushing-docker-image-to-docker-hub-using-github-actions-76c90abe95dd](https://medium.com/@shenlu89/building-and-pushing-docker-image-to-docker-hub-using-github-actions-76c90abe95dd)
52. Does the type of server your host uses, like Apache or Nginx, really matter for a small site?, accessed March 13, 2026, [https://www.reddit.com/r/statichosting/comments/1p9jtp2/does_the_type_of_server_your_host_uses_like/](https://www.reddit.com/r/statichosting/comments/1p9jtp2/does_the_type_of_server_your_host_uses_like/)
53. Serving static files with amazon s3 vs nginx - Server Fault, accessed March 13, 2026, [https://serverfault.com/questions/275393/serving-static-files-with-amazon-s3-vs-nginx](https://serverfault.com/questions/275393/serving-static-files-with-amazon-s3-vs-nginx)
54. Introducing Spin 2.0 - Fermyon, accessed March 13, 2026, [https://www.fermyon.com/blog/introducing-spin-v2](https://www.fermyon.com/blog/introducing-spin-v2)
55. docs/docs/start/build-and-run/docker_wasm.md at main · WasmEdge/docs - GitHub, accessed March 13, 2026, [https://github.com/wasmedge/docs/blob/main/docs/start/build-and-run/docker_wasm.md](https://github.com/wasmedge/docs/blob/main/docs/start/build-and-run/docker_wasm.md)
