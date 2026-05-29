# ANTIGRAVITY.md — CI-Static-Containter-Builder

## Context

**CI-Static-Containter-Builder** — **Infrastructure** layer of the Companion Intelligence platform (Lifescope Inc).

Architecture: `CI-Engineering/architecture/architecture.md`
Roadmap: `CI-Engineering/architecture/roadmap.md`

## Purpose

Static container image builder for CI platform components.

## Stack

- Docker / Dockerfile
- Shell scripts

## Commands

```bash
# no install
docker build .
docker build . && docker run ...
```

## Rules

- Package manager: do not switch or mix.
- Destructive git operations (`reset --hard`, `clean -f`) require explicit user confirmation.
- Commits reference CI-Engineering issues.
- All content is **private and confidential** — Property of Lifescope Inc.
