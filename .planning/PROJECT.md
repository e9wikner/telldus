# Telldus Core Modern Linux Support

## What This Is

This project modernizes the existing Telldus Core codebase so it can compile and run headlessly on current Linux systems, especially Arch Linux for local development and Raspberry Pi OS/Debian on `aarch64` for Home Assistant-adjacent deployment. The first goal is to restore reliable TellStick Duo operation without requiring TelldusCenter, Qt GUI components, device re-pairing, or replacement of an existing `/etc/tellstick.conf`.

Docker is part of the target workflow: a provided TellStick configuration file should be bind-mounted into a container as `/etc/tellstick.conf`, the daemon should run there, and the setup should behave like the same device connected to the Raspberry Pi. Native Linux support remains equally important so Telldus Core can run directly on Arch Linux or Raspberry Pi OS when desired.

## Core Value

Existing 433 MHz devices controlled by a TellStick Duo must keep working on modern Linux, using the existing configuration file, without re-learning or re-pairing devices.

## Requirements

### Validated

- ✓ Telldus Core has a headless service/client architecture with a daemon, shared C API, and `tdtool` CLI — existing
- ✓ TellStick Duo hardware support exists through the Telldus service, controller manager, and libftdi/ftd2xx backends — existing
- ✓ Device definitions are read from `tellstick.conf` and device state is managed separately — existing
- ✓ The codebase already includes protocol implementations for many 433 MHz devices and sensors — existing
- ✓ The codebase already exposes callbacks/events for devices, raw device data, sensors, and controllers — existing
- ✓ The codebase includes optional tests for common utilities and protocol behavior — existing

### Active

- [ ] Build the Linux headless Telldus Core components on modern systems without requiring TelldusCenter or Qt GUI dependencies
- [ ] Support native builds on Arch Linux for local development and Raspberry Pi OS/Debian `aarch64` for deployment
- [ ] Support Docker builds/runs where `/etc/tellstick.conf` is provided by bind mount
- [ ] Run `telldusd` in Docker with a TellStick Duo passed through from the host
- [ ] Preserve compatibility with an existing TellStick Duo configuration file so existing 433 MHz devices do not need to be re-paired
- [ ] Verify basic TellStick Duo runtime behavior: USB detection, daemon startup, config loading, switching/dimming configured devices, receiving raw/sensor events where hardware supports it, and surviving daemon/container/service restart
- [ ] Keep `tdtool` available for verification and backwards-compatible control during v1
- [ ] Document native and Docker setup steps clearly enough to reproduce on Arch Linux and Raspberry Pi OS/Debian

### Out of Scope

- TelldusCenter GUI modernization — the immediate product is headless Linux support and the Qt 4 GUI is not needed
- Windows, macOS, and FreeBSD support — v1 targets Linux only
- Re-pairing, re-learning, or rewriting the user’s existing 433 MHz device setup — preserving the existing config is a core constraint
- MQTT and Home Assistant MQTT discovery — important future goal, but deferred until Linux core runtime is stable
- Replacing `tdtool` in v1 — it remains useful as a stable verification and compatibility tool
- Broad C++ modernization unrelated to compiling/running on modern Linux — refactors should stay tied to the runtime goal

## Context

The existing repository is a legacy Telldus/TellStick codebase. The codebase map in `.planning/codebase/` identifies the main headless components:

- `telldus-core/service/` builds the service daemon (`telldusd` on Linux) and owns controller, device, protocol, settings, sensor, and event handling.
- `telldus-core/client/` builds the shared C API library used by clients and bindings.
- `telldus-core/tdtool/` builds the CLI used for listing devices/sensors and sending commands.
- `telldus-core/common/` provides shared socket, message, event, threading, mutex, and string utilities.
- `telldus-gui/` builds TelldusCenter and Qt 4 plugins, but this is explicitly not part of v1.

Current runtime target:

- Development host: Arch Linux on this machine.
- Deployment target: Raspberry Pi OS/Debian `aarch64`, specifically a Raspberry Pi/Home Assistant environment with kernel `Linux homeassistant 6.12.75+rpt-rpi-v8 #1 SMP PREEMPT Debian 1:6.12.75-1+rpt1 (2026-03-11) aarch64`.
- Hardware: TellStick Duo available for local or Raspberry Pi testing.
- Configuration: user will provide an existing TellStick configuration file to mount as `/etc/tellstick.conf`.

Docker is not just a packaging nicety. It is a test and runtime strategy: the container should run with the same config path and hardware access assumptions as the Raspberry Pi deployment.

## Constraints

- **Scope**: Linux-only v1 — avoids spending effort on Windows/macOS/FreeBSD code paths that are not needed now.
- **UI**: No TelldusCenter/Qt GUI work — avoids Qt 4 dependency and keeps the deliverable headless.
- **Hardware**: TellStick Duo must be testable — compile-only success is not enough for v1.
- **Configuration**: Existing `/etc/tellstick.conf` compatibility is mandatory — users should not need to re-learn devices around the house.
- **Runtime**: Docker and native Linux both matter — Docker should support bind-mounted config and USB device passthrough; native should work directly on Arch and Raspberry Pi OS/Debian.
- **Verification**: `tdtool` remains part of v1 — it is the existing control surface for proving runtime behavior before MQTT exists.
- **Future Integration**: MQTT/Home Assistant is deferred — design choices should not block it, but v1 should not depend on it.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Target headless Linux first | The needed deployment is Raspberry Pi/Home Assistant, and TelldusCenter is not required | — Pending |
| Exclude TelldusCenter/Qt GUI from v1 | Qt 4 GUI modernization would distract from restoring working TellStick Duo runtime | — Pending |
| Preserve existing `tellstick.conf` | Existing 433 MHz devices are already paired around the house and should keep working | — Pending |
| Support both Docker and native Linux | Docker gives reproducible Raspberry Pi-like testing/runtime, while native support keeps local and direct deployment viable | — Pending |
| Defer MQTT/Home Assistant integration | Core compile/runtime must be stable before replacing the old `tdtool`-based control surface | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check -> still the right priority?
3. Audit Out of Scope -> reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-14 after initialization*
