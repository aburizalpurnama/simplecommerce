# ADR-001: Monorepo Structure dengan Go Workspace

**Status:** Accepted
**Date:** 2025-01-15
**Deciders:** Tech Lead, Backend Engineers

## Context
SimpleCommerce terdiri dari 8 microservices yang share
common packages (logger, errors, database, messaging).
Perlu keputusan: satu repo atau banyak repo?

## Decision
Gunakan **monorepo** dengan **Go workspace mode** (go.work).

## Consequences
**Positif:**
- Atomic cross-service changes dalam satu PR
- Shared packages tanpa version management overhead
- Unified CI/CD toolchain
- Mudah enforce coding standards

**Negatif:**
- Repo size tumbuh lebih besar seiring waktu
- CI butuh path-based filtering agar tidak build semua

## Alternatives yang Ditolak
- Polyrepo: terlalu banyak overhead untuk shared code management
- Single go.mod: tidak support independent deployment per service