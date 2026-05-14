---
phase: 3
slug: raspberry-pi-portability
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-14
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | CppUnit 1.15.1 |
| **Config file** | `telldus-core/tests/CMakeLists.txt` |
| **Quick run command** | `ctest --test-dir build/headless -R cppunit --output-on-failure` |
| **Full suite command** | `ctest --test-dir build/headless -R cppunit --output-on-failure` |
| **Estimated runtime** | ~30 seconds (test execution only; Docker build is separate) |

---

## Sampling Rate

- **After every task commit:** Run Docker multi-arch build + test + smoke for the changed component
- **After every plan wave:** Run full multi-arch build pipeline (amd64 and arm64)
- **Before `/gsd-verify-work`:** Full suite must be green on both architectures
- **Max feedback latency:** 600 seconds (QEMU emulation builds are slower)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 1 | NBLD-03 | — | Debian dependency script installs all required packages | integration | `docker run --rm debian:bookworm-slim bash -c 'apt-get update && apt-get install -y <packages>'` | ❌ W0 | ⬜ pending |
| 3-02-01 | 02 | 2 | NBLD-03 | — | Headless components compile on Debian aarch64 | integration | `docker run --rm --platform linux/arm64 -v $(pwd):/src:ro debian:bookworm-slim ... cmake --build ...` | ❌ W0 | ⬜ pending |
| 3-02-02 | 02 | 2 | NBLD-03 | — | CppUnit tests pass on Debian aarch64 | integration | `ctest --test-dir build/headless -R cppunit --output-on-failure` inside arm64 container | ❌ W0 | ⬜ pending |
| 3-02-03 | 02 | 2 | NBLD-03 | — | `tdtool` binary runs on Debian aarch64 | smoke | `./build/headless/tdtool/tdtool --help` inside arm64 container | ❌ W0 | ⬜ pending |
| 3-03-01 | 03 | 3 | NBLD-03 | — | Built binaries are verified as ARM aarch64 ELF | smoke | `file build/headless/service/telldusd` shows `ARM aarch64` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/install-debian-deps.sh` — Debian dependency installer
- [ ] Dockerfile or documented inline Docker commands for multi-arch build
- [ ] Architecture verification step (`file` command on built binaries)

*Wave 0 creates build infrastructure; existing CppUnit test infrastructure covers all runtime verification needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Native Raspberry Pi OS build | NBLD-03 | Physical Pi hardware may not be available | If Pi hardware is accessible, run `scripts/install-debian-deps.sh` and `cmake --preset headless` natively |

*If Pi hardware is unavailable, Docker multi-arch build provides equivalent verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 600s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
