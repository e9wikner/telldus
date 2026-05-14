# Requirements: Telldus Core Modern Linux Support

**Defined:** 2026-05-14
**Core Value:** Existing 433 MHz devices controlled by a TellStick Duo must keep working on modern Linux, using the existing configuration file, without re-learning or re-pairing devices.

## v1 Requirements

Requirements for the initial release. Each maps to roadmap phases.

### Native Linux Build

- [x] **NBLD-01**: Developer can configure the headless Telldus Core build on Arch Linux without requiring TelldusCenter or Qt GUI dependencies
- [ ] **NBLD-02**: Developer can build `telldusd`, `libtelldus-core`, and `tdtool` on Arch Linux using documented system dependencies
- [ ] **NBLD-03**: Developer can configure and build the same headless components for Raspberry Pi OS/Debian `aarch64`
- [ ] **NBLD-04**: Developer can run automated core tests that are practical on modern Linux without requiring TellStick hardware

### Docker Runtime

- [ ] **DOCK-01**: Developer can build a Docker image that contains only the Linux headless runtime components and their required runtime dependencies
- [ ] **DOCK-02**: Operator can run `telldusd` in a container with a host TellStick Duo passed through to the container
- [ ] **DOCK-03**: Operator can bind-mount an existing config file into the container as `/etc/tellstick.conf`
- [ ] **DOCK-04**: Operator can use `tdtool` against the containerized daemon for device listing and command verification
- [ ] **DOCK-05**: Container startup and restart preserve the expected config and runtime behavior without requiring device re-learning

### TellStick Duo Runtime

- [ ] **DUO-01**: Operator can connect a TellStick Duo and have the Linux daemon detect it over USB
- [ ] **DUO-02**: Operator can start `telldusd` successfully on modern Linux with the TellStick Duo connected
- [ ] **DUO-03**: Operator can list configured devices from the existing `tellstick.conf` using `tdtool`
- [ ] **DUO-04**: Operator can switch existing configured devices on and off using `tdtool`
- [ ] **DUO-05**: Operator can dim existing configured devices that support dimming using `tdtool`
- [ ] **DUO-06**: Operator can observe raw device or sensor events from the TellStick Duo where the connected hardware and configured devices support receiving
- [ ] **DUO-07**: Operator can restart the daemon, container, or host service without losing compatibility with the existing device configuration

### Configuration Compatibility

- [ ] **CONF-01**: Existing `tellstick.conf` files remain compatible with the modernized Linux runtime
- [ ] **CONF-02**: Runtime state remains separate from the user-provided `tellstick.conf`
- [ ] **CONF-03**: Documentation explains exactly how to provide the existing config for native and Docker runs
- [ ] **CONF-04**: No v1 workflow requires re-pairing, re-learning, or editing every existing 433 MHz device

### Documentation and Operations

- [ ] **DOCS-01**: Developer can follow documented native build instructions for Arch Linux
- [ ] **DOCS-02**: Developer can follow documented native build instructions for Raspberry Pi OS/Debian `aarch64`
- [ ] **DOCS-03**: Operator can follow documented Docker build and run instructions, including config mount and USB device passthrough
- [ ] **DOCS-04**: Operator has a concise manual verification checklist for TellStick Duo behavior
- [ ] **DOCS-05**: Documentation clearly states that TelldusCenter/Qt GUI, Windows, macOS, FreeBSD, and MQTT are outside v1

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### MQTT and Home Assistant

- **MQTT-01**: Operator can run an MQTT bridge for Telldus devices without relying on ad hoc `tdtool` shell calls
- **MQTT-02**: Home Assistant can discover or configure Telldus devices through MQTT
- **MQTT-03**: MQTT state updates reflect TellStick Duo device events where receive support is available
- **MQTT-04**: MQTT command topics can control existing configured devices without changing their Telldus IDs or pairing state

### Packaging and Service Management

- **PKG-01**: Operator can install native Linux packages for supported distributions
- **PKG-02**: Operator can run `telldusd` under a documented systemd unit outside Docker
- **PKG-03**: Project can publish multi-architecture container images for `amd64` and `arm64`

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| TelldusCenter GUI modernization | v1 is headless Linux support; Qt 4 GUI work would distract from core runtime restoration |
| Windows support | Current deployment target is Linux only |
| macOS support | Current deployment target is Linux only |
| FreeBSD support | Current deployment target is Linux only |
| Device re-pairing workflow | Existing paired 433 MHz devices must keep working from the existing config |
| MQTT bridge in v1 | Useful next milestone, but core build/runtime must work first |
| Home Assistant MQTT discovery in v1 | Depends on the MQTT bridge and is deferred |
| Broad C++ rewrite | Modernization should be limited to what is needed for modern Linux build/runtime success |
| Telldus Live integration | Not needed for local TellStick Duo/Home Assistant use |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| NBLD-01 | Phase 1 | Complete |
| NBLD-02 | Phase 2 | Pending |
| NBLD-03 | Phase 3 | Pending |
| NBLD-04 | Phase 2 | Pending |
| DOCK-01 | Phase 5 | Pending |
| DOCK-02 | Phase 6 | Pending |
| DOCK-03 | Phase 5 | Pending |
| DOCK-04 | Phase 6 | Pending |
| DOCK-05 | Phase 6 | Pending |
| DUO-01 | Phase 7 | Pending |
| DUO-02 | Phase 6 | Pending |
| DUO-03 | Phase 7 | Pending |
| DUO-04 | Phase 7 | Pending |
| DUO-05 | Phase 7 | Pending |
| DUO-06 | Phase 7 | Pending |
| DUO-07 | Phase 6 | Pending |
| CONF-01 | Phase 4 | Pending |
| CONF-02 | Phase 4 | Pending |
| CONF-03 | Phase 5 | Pending |
| CONF-04 | Phase 4 | Pending |
| DOCS-01 | Phase 8 | Pending |
| DOCS-02 | Phase 8 | Pending |
| DOCS-03 | Phase 8 | Pending |
| DOCS-04 | Phase 7 | Pending |
| DOCS-05 | Phase 8 | Pending |

**Coverage:**
- v1 requirements: 25 total
- Mapped to phases: 25
- Unmapped: 0

---
*Requirements defined: 2026-05-14*
*Last updated: 2026-05-14 after Phase 1 completion*
