---
phase: 05
slug: docker-image-and-config-mount
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-15
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | CppUnit (embedded in telldus-core build) + Docker smoke tests |
| **Config file** | `CMakePresets.json` (headless preset enables `ENABLE_TESTING=TRUE`) |
| **Quick run command** | `ctest --test-dir build/headless -R cppunit --output-on-failure` |
| **Full suite command** | `ctest --test-dir build/headless --output-on-failure` |
| **Estimated runtime** | ~30 seconds (CppUnit) + ~2 minutes (Docker build) |

---

## Sampling Rate

- **After every task commit:** Run `docker build --target build -t telldus:build .`
- **After every plan wave:** Run `docker build -t telldus . && docker run --rm telldus tdtool --help`
- **Before `/gsd-verify-work`:** Full multi-arch build must succeed
- **Max feedback latency:** ~5 minutes (Docker build)
  - Note: Image construction is inherently integration-level. Full `docker build` verification takes ~2 minutes and cannot be reduced below ~30 seconds without sacrificing correctness. This exceeds the Nyquist 30-second threshold for per-task sampling but is acceptable for a build phase where the primary artifact is a container image.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | DOCK-01 | — | Image contains only headless runtime | build | `docker build -t telldus .` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | DOCK-01 | — | CppUnit tests pass during build | build | `docker build --target build -t telldus:build .` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 2 | DOCK-03 | — | Config bind mount provides /etc/tellstick.conf | smoke | `docker run --rm -v $(pwd)/test.conf:/etc/tellstick.conf:ro telldus cat /etc/tellstick.conf` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 2 | DOCK-03 | — | Sample config exists as fallback | smoke | `docker run --rm telldus cat /etc/tellstick.conf` | ❌ W0 | ⬜ pending |
| 05-03-01 | 03 | 3 | D-05-08 | — | Default entrypoint runs telldusd --nodaemon | smoke | `docker inspect --format='{{.Config.Cmd}}' telldus | grep 'telldusd --nodaemon'` | ❌ W0 | ⬜ pending |
| 05-03-02 | 03 | 3 | D-05-09 | — | One-shot tdtool dispatch works | smoke | `docker run --rm telldus tdtool --help` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Dockerfile` — multi-stage build definition for DOCK-01
- [ ] `scripts/build-docker.sh` — multi-arch build helper for D-05-15
- [ ] `scripts/docker-entrypoint.sh` — dual-mode entrypoint for D-05-08, D-05-09
- [ ] `.dockerignore` — prevents build context bloat
- [ ] `scripts/smoke-test-docker.sh` — image verification smoke tests

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Multi-arch manifest push | DOCK-14 | Requires registry credentials | Build with `docker buildx --push` and verify manifest on registry |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
