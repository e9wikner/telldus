# Phase 8 Context: Operator Documentation

## Domain

Phase 8 delivers comprehensive operator-facing documentation that enables developers and operators to build, configure, and run Telldus Core on modern Linux systems (Arch Linux for development, Raspberry Pi OS/Debian `aarch64` for deployment).

## Decisions

### Documentation Structure

**Decision D-08-01:** Create two primary documentation files
- `README.md` at repository root: Full but concise guide (~200 lines)
- `QUICKSTART.md` at repository root: Ultra-terse reference for immediate use

**Rationale:** Single comprehensive README was considered but would be too long. Two-file approach balances completeness with accessibility.

**Decision D-08-02:** Consolidate existing docs/ content into main documentation files
- Existing detailed docs (docker-runtime.md, VERIFICATION.md, hardware-verification.md) will be absorbed or referenced
- Avoid maintaining parallel documentation in docs/ folder
- Keep docs/ only for protocol documentation (*.dox files) and generated artifacts

### Audience Targeting

**Decision D-08-03:** Use separate entry points for different audiences
- Primary documentation split:
  - README.md: Complete but concise coverage for all users
  - QUICKSTART.md: Essential commands only, no explanations
- No separate BUILDING.md or OPERATING.md files to keep file count minimal

**Decision D-08-04:** Progressive disclosure within README
- Start with Docker quickstart (primary use case)
- Follow with native build sections for Arch and Debian/RPi
- End with troubleshooting and v2 roadmap
- Platform-specific notes inline rather than separate sections

### Content Organization

**Decision D-08-05:** README sections (in order)
1. Overview (what this is, core value)
2. Prerequisites (hardware, software, config file)
3. Quickstart - Docker (one-liner to running container)
4. Docker Operation (detailed Docker usage, compose, volumes)
5. Native Build - Arch Linux (step-by-step)
6. Native Build - Raspberry Pi OS/Debian (step-by-step)
7. Configuration (tellstick.conf format, reloading)
8. Verification (testing commands, expected outputs)
9. Troubleshooting (common issues, quick fixes)
10. What's Next (v2: MQTT, Home Assistant, packaging)

**Decision D-08-06:** QUICKSTART.md content
- Copy-paste commands only
- No explanatory text
- Both Docker and native paths covered
- Links to README for "why" and troubleshooting

### Scope and Boundaries

**Decision D-08-07:** Documentation scope
- Include: Build, configuration, operation, verification
- Exclude: Protocol details (link to existing .dox files)
- Exclude: GUI/TelldusCenter instructions (explicitly out of scope per v1)
- Exclude: Windows/macOS/FreeBSD instructions (Linux-only v1)

**Decision D-08-08:** Reference existing phase artifacts
- Link to .planning/phases/ CONTEXT.md and SUMMARY.md files for implementation details
- Don't duplicate phase research/planning content in user-facing docs
- README focuses on "how to use" not "how it was built"

## Prior Decisions Carried Forward

From PROJECT.md and prior phases:
- Target both native Linux and Docker workflows (not either/or)
- Support Arch Linux (development) and Raspberry Pi OS/Debian `aarch64` (deployment)
- Preserve existing `tellstick.conf` compatibility (no re-pairing needed)
- `tdtool` remains the primary CLI interface for v1
- MQTT/Home Assistant explicitly deferred to v2
- TelldusCenter/Qt GUI out of scope for v1

## Canonical References

These documents contain essential information that may be referenced or summarized:

- `.planning/PROJECT.md` - Project overview, constraints, key decisions
- `.planning/REQUIREMENTS.md` - v1 requirements mapping (DOCS-01 through DOCS-05)
- `.planning/ROADMAP.md` - Phase 8 definition and success criteria
- `docs/docker-runtime.md` - Detailed Docker runtime documentation (to be consolidated)
- `docs/VERIFICATION.md` - Container verification checklist (to be consolidated)
- `docs/hardware-verification.md` - Hardware testing procedures (to be consolidated)
- `.planning/phases/01-headless-build-boundary/01-CONTEXT.md` - Build boundary decisions
- `.planning/phases/02-arch-native-build/02-CONTEXT.md` - Arch build decisions
- `.planning/phases/03-raspberry-pi-portability/03-CONTEXT.md` - Debian/RPi decisions
- `.planning/phases/04-config-compatibility/04-CONTEXT.md` - Config reload decisions
- `.planning/phases/05-docker-image-and-config-mount/05-CONTEXT.md` - Docker image decisions
- `.planning/phases/06-containerized-daemon-runtime/06-CONTEXT.md` - Runtime decisions
- `.planning/phases/07-tellstick-duo-hardware-verification/07-CONTEXT.md` - Hardware verification decisions

## Code Context

### Reusable Assets

**Scripts to reference in documentation:**
- `scripts/install-arch-deps.sh` - Arch Linux dependency installation
- `scripts/install-debian-deps.sh` - Debian/RPi dependency installation
- `scripts/build-docker.sh` - Docker image build script
- `scripts/run-telldus.sh` - Container run script
- `scripts/smoke-test-docker.sh` - Docker smoke test
- `scripts/test-container-runtime.sh` - Container runtime test
- `scripts/docker-entrypoint.sh` - Container entrypoint (document behavior)

**Configuration files to document:**
- `Dockerfile` - Container image definition
- `docker-compose.yml` - Compose orchestration
- `CMakePresets.json` - Build presets

### Integration Points

Documentation should connect with:
- CMake build system (headless preset)
- Docker runtime (privileged mode, volume mounts)
- tellstick.conf configuration format
- tdtool CLI interface

## Deferred Ideas

Documentation ideas deferred to v2 or future phases:
- MQTT integration guide (deferred to v2)
- Home Assistant MQTT discovery setup (deferred to v2)
- Native packaging instructions (APK, DEB packages - deferred)
- Systemd service setup guide (deferred - Docker primary for now)
- TelldusCenter GUI documentation (explicitly out of scope for v1)

## Acceptance Criteria

Per REQUIREMENTS.md DOCS-01 through DOCS-05:

- [ ] Developer can follow documented native build instructions for Arch Linux
- [ ] Developer can follow documented native build instructions for Raspberry Pi OS/Debian `aarch64`
- [ ] Operator can follow documented Docker build and run instructions, including config mount and USB device passthrough
- [ ] Documentation clearly states that TelldusCenter/Qt GUI, Windows, macOS, FreeBSD, and MQTT are outside v1

Success means a new user can:
1. Clone the repo
2. Follow README.md to build (native) or run (Docker)
3. Successfully control a TellStick Duo with their existing config
4. Know what's coming in v2

---
*Created: 2026-05-15*
*Discussion: Documentation structure, audience targeting*
