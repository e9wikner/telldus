# Phase 3: Raspberry Pi Portability - Discussion Log

**Gathered:** 2026-05-14T21:30:00+02:00
**Areas discussed:** Build verification method, Debian dependency mapping, CMake preset strategy, Architecture-specific code audit

---

## Build Verification Method

**Question:** How should we verify the aarch64 build in Phase 3?
**Options presented:**
- Docker multi-arch build (Recommended) — reproducible, no real Pi needed, sets up Phase 5 infra
- Native cross-compile from Arch — fastest but doesn't prove runtime linking
- SSH to real Raspberry Pi — most realistic but requires hardware
- QEMU VM with Debian aarch64 — faithful but heavy
**Selected:** Docker multi-arch build

**Question:** Should the Docker build run tests or only compile?
**Options presented:**
- Compile only (faster)
- Compile + run tests (Recommended)
- Compile + all tests + tdtool smoke test
**Selected:** Compile + all tests + tdtool smoke test

**Question:** Which Debian base image?
**Options presented:**
- debian:bookworm-slim (Recommended)
- balenalib/rpi-debian
- ubuntu:24.04
**Selected:** debian:bookworm-slim

---

## Debian Dependency Mapping

**Question:** How should Debian dependencies be captured?
**Options presented:**
- Create scripts/install-debian-deps.sh (Recommended)
- Document in README only
- Single unified install script with OS detection
**Selected:** Create scripts/install-debian-deps.sh

**Question:** Should the Debian script include build tools explicitly?
**Options presented:**
- Include everything (Recommended) — cmake, build-essential, libftdi1-dev, etc.
- Assume build tools present
**Selected:** Include everything

---

## CMake Preset Strategy

**Question:** Should the CMake preset strategy change for Debian/aarch64?
**Options presented:**
- Reuse headless preset (Recommended) — architecture-agnostic
- Add a debian-aarch64 preset
- Rename headless to linux-headless
**Selected:** Reuse headless preset

---

## Architecture-Specific Code Audit

**Question:** How deep should the architecture audit go?
**Options presented:**
- Grep for known risk patterns (Recommended)
- Full static analysis with cppcheck
- Build-and-observe only
**Selected:** Build-and-observe only

---

## Decisions Summary

| ID | Decision |
|----|----------|
| D-03-01 | Use Docker multi-arch build (`docker buildx --platform linux/arm64`) |
| D-03-02 | Base image: `debian:bookworm-slim` |
| D-03-03 | Container must compile, run CppUnit tests, and smoke-test `tdtool` |
| D-03-04 | Create `scripts/install-debian-deps.sh` |
| D-03-05 | Include all deps: cmake, build-essential, libftdi1-dev, libconfuse-dev, libusb-1.0-0-dev, pkg-config, libcppunit-dev |
| D-03-06 | Reuse existing `headless` CMake preset |
| D-03-07 | No Debian-specific preset unless build surfaces real need |
| D-03-08 | Build-and-observe only for architecture audit |
| D-03-09 | Fix specific issues if build fails; no preemptive refactoring |

## Deferred Ideas

None.

## Next Steps

- `/gsd-plan-phase 03-raspberry-pi-portability` — create detailed plans
- `/gsd-execute-phase 03-raspberry-pi-portability` — execute plans after planning
