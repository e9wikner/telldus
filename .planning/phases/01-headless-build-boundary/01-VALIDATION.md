---
phase: 1
slug: headless-build-boundary
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-14
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | CMake configure/build proof; optional CTest/CppUnit boundary |
| **Config file** | `telldus-core/CMakeLists.txt` |
| **Quick run command** | `cmake -S telldus-core -B build/telldus-core-headless -DFORCE_COMPILE_FROM_TRUNK=TRUE -DBUILD_TDTOOL=TRUE -DBUILD_TDADMIN=FALSE -DENABLE_TESTING=FALSE -DFTDI_ENGINE=libftdi` |
| **Full suite command** | `cmake --build build/telldus-core-headless --target telldusd telldus-core tdtool -- -n` |
| **Estimated runtime** | ~60 seconds after dependencies are installed |

---

## Sampling Rate

- **After every task commit:** Run the quick configure command when `cmake` is available; otherwise record `cmake: command not found` as an environment blocker.
- **After every plan wave:** Run the full dry build proof command when configure succeeds.
- **Before `$gsd-verify-work`:** Configure proof, dry build proof, and committed build instructions must exist.
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01-01 | 1 | NBLD-01 | — | N/A | source/doc | `rg -n "BUILD_TDTOOL|BUILD_TDADMIN|ENABLE_TESTING|SignTool|FTDI_ENGINE" telldus-core` | ✅ | ⬜ pending |
| 01-02-01 | 01-02 | 2 | NBLD-01 | — | N/A | configure | `cmake -S telldus-core -B build/telldus-core-headless -DFORCE_COMPILE_FROM_TRUNK=TRUE -DBUILD_TDTOOL=TRUE -DBUILD_TDADMIN=FALSE -DENABLE_TESTING=FALSE -DFTDI_ENGINE=libftdi` | ❌ W0 if cmake missing | ⬜ pending |
| 01-03-01 | 01-03 | 3 | NBLD-01 | — | N/A | dry-build/docs | `cmake --build build/telldus-core-headless --target telldusd telldus-core tdtool -- -n` | ❌ W0 if cmake missing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `cmake` available in local environment, or environment blocker documented before dry build proof.
- [ ] `build/telldus-core-headless/` can be created by the configure command.
- [ ] Project docs location for headless build instructions selected or created.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No Qt/TelldusCenter dependency in headless path | NBLD-01 | Dependency absence is best confirmed by inspecting configure output and build files | Configure from `telldus-core/`; confirm no Qt or `telldus-gui` paths are required |
| ftd2xx remains harmless or out of Linux v1 | NBLD-01 | Depends on build-file branch inspection | Confirm Linux proof uses `FTDI_ENGINE=libftdi`; do not require ftd2xx to pass |
| Boundary docs are reproducible | NBLD-01 | Documentation quality requires human review | Follow committed commands from a clean checkout or clean build directory |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
