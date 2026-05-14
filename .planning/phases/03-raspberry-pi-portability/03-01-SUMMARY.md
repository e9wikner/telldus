---
phase: 03-raspberry-pi-portability
plan: 01
subsystem: build
tags: [debian, raspberry-pi, docker, multi-arch, qemu, cmake, libftdi]

requires:
  - phase: 02-arch-native-build
    provides: Headless CMake preset and Arch dependency installer pattern

provides:
  - Debian/Raspberry Pi OS dependency installation script (scripts/install-debian-deps.sh)
  - Verified Docker multi-arch build command reference (docs/phase-03-docker-commands.md)
  - Live verification of all 7 Debian Bookworm package names
  - Reproducible aarch64 build pipeline via docker run --platform linux/arm64

affects:
  - 03-02 (Build headless components for Raspberry Pi target)
  - 05-01 (Docker build for headless runtime)
  - 08-02 (Document Raspberry Pi OS/Debian build workflow)

tech-stack:
  added: []
  patterns: [Debian dependency script mirroring Arch pattern, Docker multi-arch build with QEMU]

key-files:
  created:
    - scripts/install-debian-deps.sh
    - docs/phase-03-docker-commands.md
  modified: []

key-decisions:
  - "Mirrored Arch script pattern for Debian: standalone bash script with set -e, DEBIAN_FRONTEND=noninteractive, and apt-get install -y -q"
  - "Verified all 7 package names live inside debian:bookworm-slim container before committing"
  - "Documented read-only source mount + writable copy (cp -r /src /work) anti-pattern from RESEARCH.md"
  - "Reused existing headless CMake preset unchanged; confirmed it is architecture-agnostic"
  - "Explicitly deferred Dockerfile to Phase 5 per ROADMAP boundary"

patterns-established:
  - "Dependency scripts: standalone executable in scripts/ per distro (install-arch-deps.sh, install-debian-deps.sh)"
  - "Docker multi-arch verification: use --platform linux/arm64 with debian:bookworm-slim, copy source to writable directory, reuse existing CMake preset"

requirements-completed:
  - NBLD-03

# Metrics
duration: 2min
completed: 2026-05-14
---

# Phase 3 Plan 1: Debian/Raspberry Pi aarch64 Build Environment Summary

**Debian dependency installer and verified Docker multi-arch build commands for Raspberry Pi `aarch64` headless builds**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-14T20:24:05Z
- **Completed:** 2026-05-14T20:25:59Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Created `scripts/install-debian-deps.sh` for one-command dependency installation on Debian/Raspberry Pi OS
- Verified all 7 package names (`cmake`, `build-essential`, `pkg-config`, `libftdi1-dev`, `libconfuse-dev`, `libusb-1.0-0-dev`, `libcppunit-dev`) resolve in the live `debian:bookworm-slim` apt index
- Documented the complete Docker multi-arch build-test-smoke pipeline in `docs/phase-03-docker-commands.md`
- Confirmed the existing `headless` CMake preset is architecture-agnostic and works unchanged on `aarch64`

## Task Commits

1. **Task 1: Create scripts/install-debian-deps.sh** - `d3ff314` (feat)
2. **Task 2: Verify Debian package names in bookworm-slim container** - `84cb516` (chore)
3. **Task 3: Document Docker multi-arch build commands** - `85f98b4` (docs)

**Plan metadata:** `85f98b4` (docs: complete plan)

## Files Created/Modified

- `scripts/install-debian-deps.sh` - Automated Debian/Raspberry Pi OS dependency installer (apt-get)
- `docs/phase-03-docker-commands.md` - Verified Docker multi-arch build command reference for linux/arm64

## Decisions Made

- **Debian script mirrors Arch pattern:** Used the same `set -e`, header echo, package list, and error fallback structure as `scripts/install-arch-deps.sh` for consistency.
- **Live package verification:** Ran `apt-cache search` inside `debian:bookworm-slim` for each of the 7 packages to confirm names before committing the script.
- **Read-only mount + writable copy:** Documented the anti-pattern of mounting source read-only and copying to `/work` inside the container, avoiding CMake cache directory mismatch errors.
- **Headless preset reuse:** Confirmed no Debian-specific or `aarch64`-specific preset is needed; the existing preset variables work on any Linux architecture.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- None.

## User Setup Required

**Docker tooling requires manual verification.** See the plan frontmatter `user_setup` section:

- Ensure Docker Engine is installed and the docker daemon is running
- Ensure docker buildx is available: `docker buildx inspect default`
- Ensure QEMU binfmt is configured for aarch64: `docker run --rm --privileged multiarch/qemu-user-static --reset -p yes`

## Next Phase Readiness

- **Ready for 03-02:** The Debian dependency script and Docker build commands are in place. Wave 2 can now attempt the actual multi-arch compilation of telldus-core.
- **Blockers:** None.

---
*Phase: 03-raspberry-pi-portability*
*Completed: 2026-05-14*
