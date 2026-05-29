# AGENTS.md — CI-Static-Containter-Builder

## Platform context

CI-Static-Containter-Builder is the **Infrastructure** layer component of the Companion Intelligence platform — a private, local-first digital memory system.

Full architecture: `CI-Engineering/architecture/architecture.md`

## Repo summary

Static container image builder for CI platform components.

## Stack

- Docker / Dockerfile
- Shell scripts

## Setup & commands

```bash
# no install   # install
docker build .   # dev
docker build . && docker run ...   # test
docker build .   # build
```



## Git discipline

- Never `git reset --hard` or `git clean -f` without user confirmation.
- Commit messages: imperative mood, ≤ 72 chars.
- Reference CI-Engineering issues in PRs (e.g. `Closes companionintelligence/CI-Engineering#32`).

## Confidentiality

Private & Confidential — Property of Lifescope Inc. Do not distribute.
