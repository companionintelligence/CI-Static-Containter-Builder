# CLAUDE.md — CI-Static-Containter-Builder

> **Private & Confidential — Property of Lifescope Inc. Do not distribute.**

## Platform role

**CI-Static-Containter-Builder** sits in the **Infrastructure** layer of the Companion Intelligence platform.

Architecture: `CI-Engineering/architecture/architecture.md`
Roadmap: `CI-Engineering/architecture/roadmap.md`
Issues: <https://github.com/companionintelligence/CI-Engineering/issues>

## What this repo does

Static container image builder for CI platform components.

## Stack

- Docker / Dockerfile
- Shell scripts

## Key commands

```bash
# Install dependencies
# no install

# Start development server / service
docker build .

# Run tests
docker build . && docker run ...

# Build for production
docker build .
```

## Package manager

**bash** — use exclusively; do not mix with npm/yarn/pnpm/bun unless the repo explicitly requires it.

## Cross-repo connections

- Produces images consumed by CI-Hub and CI-Marketplace



## Multi-agent safety

Multiple AI agents work these repos in parallel. Never use `git reset --hard`, `git clean -f`, or any destructive git command without explicit confirmation from the user.

## Confidentiality

Private & Confidential — Property of Lifescope Inc. Do not distribute.
