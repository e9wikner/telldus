---
phase: 04
slug: config-compatibility
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-15
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | CMake build + shell integration tests + daemon smoke tests |
| **Config file** | `telldus-core/service/CMakeLists.txt` (path defaults), `telldus-core/service/SettingsConfuse.cpp` (runtime behavior) |
| **Quick run command** | `cmake -B build/headless -DFORCE_COMPILE_FROM_TRUNK=TRUE -DBUILD_TDTOOL=TRUE -DBUILD_TDADMIN=FALSE -DENABLE_TESTING=TRUE -DFTDI_ENGINE=libftdi -DSTATE_INSTALL_DIR=/var/lib/telldus && cmake --build build/headless --target telldusd tdtool` |
| **Full suite command** | `bash tests/integration/config-compat-smoke.sh` (to be created in 04-02) |
| **Estimated runtime** | ~90 seconds for build; ~30 seconds for smoke tests |

---

## Sampling Rate

- **After every task commit:** Build the modified service target and verify it compiles with zero new warnings.
- **After every plan wave:** Run the wave-specific smoke test (path override, config parse, or state persistence).
- **Before `$gsd-verify-work`:** Full smoke test suite must pass, including env var override and config reload.
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 04-01 | 1 | CONF-01 | — | N/A | source | `rg "STATE_INSTALL_DIR" telldus-core/service/CMakeLists.txt` | ✅ | ⬜ pending |
| 04-01-02 | 04-01 | 1 | CONF-01 | — | N/A | build | `cmake -B build/headless ... -DSTATE_INSTALL_DIR=/var/lib/telldus` | ❌ W0 | ⬜ pending |
| 04-01-03 | 04-01 | 1 | CONF-02 | — | N/A | integration | Shell: verify env var path override works | ❌ W0 | ⬜ pending |
| 04-02-01 | 04-02 | 2 | CONF-01 | — | N/A | integration | Shell: copy sample config, run daemon, tdtool --list-devices | ❌ W0 | ⬜ pending |
| 04-02-02 | 04-02 | 2 | CONF-01 | — | N/A | integration | Edit config, verify daemon reloads | ❌ W0 | ⬜ pending |
| 04-03-01 | 04-03 | 3 | CONF-02 | — | N/A | integration | Shell: turn device on, restart daemon, verify state | ❌ W0 | ⬜ pending |
| 04-03-02 | 04-03 | 3 | CONF-04 | — | N/A | integration | Shell: verify stable config is not overwritten by state | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `cmake` and `build-essential` available for headless build
- [ ] Shell test script scaffold exists or will be created in 04-02
- [ ] Sample realistic `tellstick.conf` exists or will be created in 04-02
- [ ] `inotify` headers available on build system (`/usr/include/sys/inotify.h`)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Existing user config loads without changes | CONF-01 | Requires a real user's existing config file | Obtain existing `tellstick.conf` from TellStick Duo setup; verify `tdtool --list-devices` shows all configured devices |
| Docker bind-mount config is writable | CONF-01 | Requires Docker runtime | Phase 5 verifies; Phase 4 prepares by documenting that the daemon writes to the mounted file |
| Device state preserved across host restart | CONF-02 | Requires full system restart | Stop daemon, verify `/var/lib/telldus/telldus-core.conf` contains state, restart host, start daemon, verify state |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
