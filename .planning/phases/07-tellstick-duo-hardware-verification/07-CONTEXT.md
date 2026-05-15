# Phase 07: TellStick Duo Hardware Verification - Context

**Gathered:** 2026-05-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 7 validates that the modernized Telldus Core runtime actually controls the real TellStick Duo hardware. This is the final proof that all prior phases (build, config, Docker) work in practice. The phase focuses on Docker-based verification as the primary deployment target, with minimal native verification.

This phase does not add new code or modify existing functionality. It is a verification phase that exercises the runtime built in Phases 1-6 against physical hardware. The output is confirmation that USB detection, device commands (on/off), and error handling work correctly.

**Scope for v1:**
- Docker container verification with USB passthrough (primary target)
- tdtool device listing from existing tellstick.conf
- On/off command transmission verification (return codes)
- Error path verification when TellStick not connected

**Out of scope for v1:**
- Native Arch Linux verification (Docker is primary)
- Dimming, bell, or learn command verification
- Sensor/receive path verification
- Long-running soak tests or stability testing
- RF packet analysis or protocol verification

</domain>

<decisions>
## Implementation Decisions

### Verification Scope
- **D-07-01:** Minimum viable verification is "tdtool lists configured devices" — the user's existing tellstick.conf loads and tdtool --list shows all devices with correct state.
- **D-07-02:** Phase 7 v1 scope includes command transmission test: tdtool --on/--off returns exit code 0 (TELLSTICK_SUCCESS).
- **D-07-03:** Success criteria is Docker as primary target. Native Arch verification is explicitly not required for Phase 7 complete.
- **D-07-04:** Sensor/receive path verification, long-running soak tests, and comprehensive protocol testing are deferred to v1.x or v2.

### Native vs Docker Priority
- **D-07-05:** Docker container with USB passthrough is the primary and only required verification target. Native Arch is development convenience only.
- **D-07-06:** Single container test is sufficient for Phase 7. No restart/resilience testing or long-running soak tests required.
- **D-07-07:** Both `docker exec` from host and interactive shell inside container are acceptable methods for running tdtool commands.

### Device Command Verification
- **D-07-08:** Verify on/off commands only (TELLSTICK_TURNON / TELLSTICK_TURNOFF). Dimming, bell, and learn commands are out of scope for Phase 7.
- **D-07-09:** Test one representative device from the tellstick.conf. Testing all devices or multiple protocols is not required.
- **D-07-10:** Verification procedure: turn on → verify success → turn off → verify success. Full cycle confirms both directions work.
- **D-07-11:** When TellStick Duo is not physically connected, verify error paths: tdtool returns TELLSTICK_ERROR_NOT_FOUND or similar error codes.

### Agent's Discretion
- The agent may structure the verification as a manual checklist, shell script, or combination — whichever makes the procedure clearest for operators.
- The agent may choose which specific device ID to test (first device in config, random selection, or parameterized).
- The agent may include optional diagnostic logging or debug output to help troubleshoot failures.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Scope
- `.planning/PROJECT.md` — Defines Linux-only headless modernization, Docker/native goals, and out-of-scope items
- `.planning/REQUIREMENTS.md` — Maps Phase 7 to DUO-01, DUO-03, DUO-04, DUO-05, DUO-06, DOCS-04
- `.planning/ROADMAP.md` — Defines Phase 7 goal, success criteria, and plan outline
- `.planning/STATE.md` — Current project position and deferred items

### Prior Phase Context (Critical)
- `.planning/phases/06-containerized-daemon-runtime/06-CONTEXT.md` — Docker runtime patterns, USB passthrough with --privileged, docker exec workflow
- `.planning/phases/05-docker-image-and-config-mount/05-CONTEXT.md` — Multi-arch Docker image, entrypoint behavior
- `.planning/phases/04-config-compatibility/04-CONTEXT.md` — Config/state paths, auto-reload behavior, env var overrides
- `.planning/phases/03-raspberry-pi-portability/03-CONTEXT.md` — Debian/aarch64 runtime considerations
- `.planning/phases/02-arch-native-build/02-CONTEXT.md` — Build artifacts and tdtool functionality

### Codebase Maps
- `.planning/codebase/STACK.md` — Build systems, dependencies (libftdi1, libconfuse), component boundaries
- `.planning/codebase/ARCHITECTURE.md` — Service/client architecture, IPC via Unix sockets
- `.planning/codebase/INTEGRATIONS.md` — Hardware integration boundaries

### Source Entry Points
- `telldus-core/service/TellStick_libftdi.cpp` — USB device access via libftdi, VID/PID detection (0x1781/0x0C31 for Duo)
- `telldus-core/service/TellStick.h` — TellStick class interface, findAll() for device discovery
- `telldus-core/service/ControllerManager.cpp` — Controller lifecycle, USB connect/disconnect handling
- `telldus-core/service/DeviceManager.cpp` — Device command execution, action dispatch
- `telldus-core/tdtool/main.cpp` — tdtool CLI implementation (--list, --on, --off, --dim)
- `telldus-core/client/telldus-core.h` — Public C API constants including TELLSTICK_SUCCESS, TELLSTICK_ERROR_NOT_FOUND
- `Dockerfile` — Multi-stage build, tini init, entrypoint script
- `scripts/docker-entrypoint.sh` — Container entrypoint with smart dispatch

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TellStick::findAll()`: Already enumerates TellStick Duo devices by VID 0x1781 / PID 0x0C31. Returns list of descriptors with serial numbers.
- `ControllerManager`: Automatically detects USB insertion/removal, manages controller lifecycle. Daemon logs controller state changes.
- `tdtool`: Complete CLI for device listing and command execution. Returns appropriate exit codes for success/failure.
- Docker image from Phase 5: Already contains telldusd, libtelldus-core.so, tdtool, and all runtime dependencies (libftdi1, libconfuse).

### Established Patterns
- USB device access: libftdi opens by vendor/product ID, not device path. Device path changes (/dev/ttyUSB0 vs /dev/ttyUSB1) are handled transparently.
- Command flow: tdtool → libtelldus-core → Unix socket → telldusd → DeviceManager → ControllerManager → TellStick::send() → libftdi_write_data()
- Error handling: Commands return integer error codes (TELLSTICK_SUCCESS=0, TELLSTICK_ERROR_NOT_FOUND, etc.). tdtool exits with non-zero on error.
- Signal handling: SIGTERM triggers graceful shutdown. Daemon does not exit on USB errors; it retries internally.

### Integration Points
- Container start: `docker run --privileged --device /dev/bus/usb -v /path/to/tellstick.conf:/etc/tellstick.conf telldus`
- tdtool access: `docker exec <container> tdtool --list` connects to running daemon via internal Unix sockets
- Config loading: Daemon reads /etc/tellstick.conf at startup, auto-reloads on changes (Phase 4 inotify watcher)
- USB passthrough: Requires --privileged for libftdi to access USB device descriptors and open the TellStick Duo

</code_context>

<specifics>
## Specific Ideas

- The user explicitly chose Docker as the primary verification target, skipping native Arch entirely. This aligns with the deployment reality (Raspberry Pi / Home Assistant adjacent).
- The verification scope is intentionally minimal: device listing + on/off commands only. This proves the core functionality without requiring extensive test equipment or device variety.
- Error path verification (without hardware connected) provides immediate feedback during development and CI, even when physical TellStick is unavailable.
- The "turn on → verify → turn off → verify" procedure is a full cycle test that exercises both directions without requiring external verification (RF sniffer, physical device observation).
- One representative device is sufficient — testing all configured devices would generate excessive RF traffic and is not required for verification.

</specifics>

<deferred>
## Deferred Ideas

- **Sensor/receive path verification** — Testing sensor decoding and raw event reception (+R/+W messages). Requires actual 433 MHz sensors. Deferred to v1.x or v2.
- **Dimming command verification** — TELLSTICK_DIM with dimlevel parameter. Protocol encoding verification. Deferred to v1.x.
- **Bell and learn commands** — TELLSTICK_BELL and TELLSTICK_LEARN methods. Device-specific features. Deferred to v1.x.
- **Native Arch verification** — The user explicitly chose to skip native verification. Docker is the supported path.
- **Long-running soak tests** — Stability testing over hours/days, memory leak detection, USB disconnect/reconnect resilience. Production hardening for v2.
- **RF packet analysis** — Using RTL-SDR or similar to verify actual RF transmission on 433.92 MHz. Advanced verification for v2.
- **Raspberry Pi hardware verification** — The user chose Docker as primary; Pi verification is implied if Docker works on arm64. Explicit Pi hardware testing can be added in v1.x if needed.

</deferred>

---

*Phase: 07-TellStick Duo Hardware Verification*
*Context gathered: 2026-05-15*
