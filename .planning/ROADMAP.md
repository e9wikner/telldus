# Roadmap: Telldus Core Modern Linux Support

## Overview

This roadmap restores Telldus Core as a modern Linux headless runtime before adding any new integration surface. The sequence is deliberately layered: isolate the GUI-free core build, prove it natively on Arch, make it portable to Raspberry Pi OS/Debian `aarch64`, preserve existing `tellstick.conf` semantics, package the runtime in Docker, validate the TellStick Duo in container and native modes, then finish with reproducible operator documentation.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Headless Build Boundary** - Separate the Linux headless target from GUI and legacy platform assumptions (completed 2026-05-14)
- [x] **Phase 2: Arch Native Build** - Build and test the headless components on the local Arch Linux machine (completed 2026-05-14)
- [x] **Phase 3: Raspberry Pi Portability** - Prove the same headless build path for Debian/Raspberry Pi `aarch64` (completed 2026-05-14)
- [x] **Phase 4: Config Compatibility** - Preserve existing `tellstick.conf` behavior and state separation (completed 2026-05-15)
- [ ] **Phase 5: Docker Image and Config Mount** - Build a minimal container image with `/etc/tellstick.conf` bind-mount support
- [ ] **Phase 6: Containerized Daemon Runtime** - Run `telldusd` and `tdtool` in Docker with restart-safe behavior
- [ ] **Phase 7: TellStick Duo Hardware Verification** - Validate USB detection, device commands, dimming, and receive paths
- [ ] **Phase 8: Operator Documentation** - Produce final native, Docker, and verification documentation

## Phase Details

### Phase 1: Headless Build Boundary
**Goal**: The project has a clear Linux-only, GUI-free build surface for Telldus Core.
**Depends on**: Nothing (first phase)
**Requirements**: NBLD-01
**Success Criteria** (what must be TRUE):
  1. Developer can configure only the Linux headless components without pulling in TelldusCenter or Qt 4.
  2. Build configuration makes it explicit which components are in v1: `telldusd`, `libtelldus-core`, and `tdtool`.
  3. Non-Linux and GUI code paths remain untouched unless a build dependency forces a minimal guard.
  4. The required Linux dependencies are identified for the headless build.
**Plans**: 3 plans

Plans:
**Wave 1**
- [x] 01-01: Audit current CMake options and dependency coupling

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 01-02: Add or adjust headless Linux build configuration

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 01-03: Verify GUI-free configuration excludes TelldusCenter and Qt dependencies

### Phase 2: Arch Native Build
**Goal**: The headless runtime builds and core tests run on the local Arch Linux development machine.
**Depends on**: Phase 1
**Requirements**: NBLD-02, NBLD-04
**Success Criteria** (what must be TRUE):
  1. Developer can build `telldusd`, `libtelldus-core`, and `tdtool` on Arch Linux.
  2. Required Arch packages and build flags are captured while implementing.
  3. Practical automated tests run without requiring TellStick hardware.
  4. Build/test failures from modern compiler or library changes are fixed or documented as explicit blockers.
**Plans**: 3 plans

Plans:
**Wave 1**
- [x] 02-01-PLAN.md — Install/confirm Arch build dependencies and run initial configure/build (completed 2026-05-14)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 02-02-PLAN.md — Fix modern compiler and dependency breakages in headless components (completed 2026-05-14)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 02-03-PLAN.md — Enable and run practical non-hardware tests (completed 2026-05-14)

### Phase 3: Raspberry Pi Portability
**Goal**: The same headless build path works for Raspberry Pi OS/Debian `aarch64`.
**Depends on**: Phase 2
**Requirements**: NBLD-03
**Success Criteria** (what must be TRUE):
  1. Developer can configure the headless build for Debian/Raspberry Pi `aarch64`.
  2. The build succeeds in a Raspberry Pi OS/Debian-like environment or on the target Raspberry Pi.
  3. Any architecture-specific assumptions found during the port are fixed in the Linux code path.
  4. The resulting artifacts match the same v1 scope as the Arch build.
**Plans**: 3 plans

Plans:
- [x] 03-01: Create or select a Debian/Raspberry Pi `aarch64` build environment
- [x] 03-02: Build the headless components for the Raspberry Pi target
- [x] 03-03: Resolve portability issues and confirm matching artifacts (completed 2026-05-14)

### Phase 4: Config Compatibility
**Goal**: Existing `tellstick.conf` files remain usable without changing paired 433 MHz devices.
**Depends on**: Phase 3
**Requirements**: CONF-01, CONF-02, CONF-04
**Success Criteria** (what must be TRUE):
  1. Operator can provide an existing `tellstick.conf` and the daemon reads configured devices from it.
  2. Runtime state remains separate from the user-provided config.
  3. No v1 operation requires re-pairing or re-learning existing devices.
  4. Config path behavior is consistent between native and Docker runs.
**Plans**: 3 plans

Plans:
- [x] 04-01: Trace Linux config and state file paths in the service
- [x] 04-02: Validate existing config loading against a user-provided sample
- [x] 04-03: Preserve config/state separation across restart scenarios (completed 2026-05-15)

### Phase 5: Docker Image and Config Mount
**Goal**: A minimal Docker image builds and accepts a bind-mounted `/etc/tellstick.conf`.
**Depends on**: Phase 4
**Requirements**: DOCK-01, DOCK-03, CONF-03
**Success Criteria** (what must be TRUE):
  1. Developer can build a container image containing only headless runtime components and runtime libraries.
  2. Operator can mount an existing config file into the container as `/etc/tellstick.conf`.
  3. The image does not include TelldusCenter or Qt GUI dependencies.
  4. Config mounting instructions are validated during implementation.
**Plans**: 3 plans

Plans:
- [x] 05-01-PLAN.md — Add Docker build for headless runtime components
- [x] 05-02-PLAN.md — Wire container entrypoint/config path behavior
- [x] 05-03-PLAN.md — Validate config bind mount and image contents

### Phase 6: Containerized Daemon Runtime
**Goal**: `telldusd` and `tdtool` work inside Docker with TellStick Duo passthrough and restart-safe behavior.
**Depends on**: Phase 5
**Requirements**: DOCK-02, DOCK-04, DOCK-05, DUO-02, DUO-07
**Success Criteria** (what must be TRUE):
  1. Operator can pass the TellStick Duo USB device into the container.
  2. `telldusd` starts successfully in the container with the mounted config.
  3. `tdtool` can talk to the containerized daemon for device listing and command checks.
  4. Container or daemon restart does not force config edits or device re-learning.
**Plans**: 4 plans

Plans:
- [ ] 06-01: Define Docker run options for USB passthrough and service permissions
- [ ] 06-02: Run `telldusd` as the container main process
- [ ] 06-03: Verify `tdtool` communication inside or against the container
- [ ] 06-04: Test daemon/container restart behavior

### Phase 7: TellStick Duo Hardware Verification
**Goal**: The modernized runtime controls and observes the real TellStick Duo setup.
**Depends on**: Phase 6
**Requirements**: DUO-01, DUO-03, DUO-04, DUO-05, DUO-06, DOCS-04
**Success Criteria** (what must be TRUE):
  1. Operator can connect a TellStick Duo and the daemon detects it over USB.
  2. Operator can list configured devices from the existing config.
  3. Operator can switch existing configured devices on and off.
  4. Operator can dim configured devices that support dimming.
  5. Operator can observe raw or sensor events where hardware and devices support receiving.
**Plans**: 4 plans

Plans:
- [ ] 07-01: Verify TellStick Duo USB detection natively and in Docker
- [ ] 07-02: Verify configured device listing and on/off commands
- [ ] 07-03: Verify dimming and receive/event behavior where available
- [ ] 07-04: Write and execute the manual hardware verification checklist

### Phase 8: Operator Documentation
**Goal**: Native and Docker operation are reproducible on Arch Linux and Raspberry Pi OS/Debian.
**Depends on**: Phase 7
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-05
**Success Criteria** (what must be TRUE):
  1. Developer can follow Arch Linux native build instructions from a clean checkout.
  2. Developer can follow Raspberry Pi OS/Debian `aarch64` native build instructions.
  3. Operator can follow Docker build/run instructions with config mount and USB passthrough.
  4. Documentation clearly states that GUI, non-Linux OSes, MQTT, and Home Assistant MQTT discovery are deferred.
**Plans**: 3 plans

Plans:
- [ ] 08-01: Document native Arch Linux build and test workflow
- [ ] 08-02: Document Raspberry Pi OS/Debian `aarch64` build and runtime workflow
- [ ] 08-03: Document Docker operation, exclusions, and next MQTT milestone

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Headless Build Boundary | 3/3 | Complete | 2026-05-14 |
| 2. Arch Native Build | 3/3 | Complete | 2026-05-14 |
| 3. Raspberry Pi Portability | 3/3 | Complete   | 2026-05-14 |
| 4. Config Compatibility | 3/3 | Complete | 2026-05-15 |
| 5. Docker Image and Config Mount | 1/3 | In Progress | 2026-05-15 |
| 6. Containerized Daemon Runtime | 0/4 | Not started | - |
| 7. TellStick Duo Hardware Verification | 0/4 | Not started | - |
| 8. Operator Documentation | 0/3 | Not started | - |
