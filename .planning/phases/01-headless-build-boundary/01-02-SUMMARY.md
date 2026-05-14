---
phase: 01-headless-build-boundary
plan: 01-02
subsystem: build
tags: [cmake, linux, headless, signtool, tdtool]
requires:
  - phase: 01-01
    provides: Phase 1 Linux headless build boundary record.
provides:
  - Explicit Linux headless CMake target boundary.
  - Non-blocking Linux SignTool lookup.
  - `tdtool` target linkage through the client library target.
affects: [phase-01, phase-02, build]
tech-stack:
  added: []
  patterns:
    - existing-cmake-options-with-guardrails
    - windows-only-required-signing
key-files:
  created: []
  modified:
    - telldus-core/CMakeLists.txt
    - telldus-core/service/CMakeLists.txt
    - telldus-core/client/CMakeLists.txt
    - telldus-core/tdtool/CMakeLists.txt
    - .planning/phases/01-headless-build-boundary/01-BUILD-BOUNDARY.md
key-decisions:
  - "`BUILD_LIBTELLDUS-CORE` is now honored, with `tdtool` and tests guarded when it is disabled."
  - "SignTool remains required on Windows only and non-required on Linux."
  - "`tdtool` links through `${telldus-core_TARGET}` on Linux."
patterns-established:
  - "Keep non-Linux behavior guarded while making Linux headless target selection explicit."
requirements-completed: [NBLD-01]
duration: 2min
completed: 2026-05-14
---

# Phase 1 Plan 01-02 Summary

**CMake headless boundary made explicit for Linux service, client library, and `tdtool` targets**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-14T16:01:41Z
- **Completed:** 2026-05-14T16:03:31Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Made `BUILD_LIBTELLDUS-CORE` control `telldus-core/client` and added clear fatal guards for dependent `tdtool` and test builds.
- Changed service/client SignTool lookup so it is required only on Windows and non-required on Linux while preserving `SIGN(...)`.
- Changed Unix `tdtool` linkage from a hard-coded `.so` path to `${telldus-core_TARGET}`.
- Updated the boundary record to reflect the current CMake behavior.

## Task Commits

1. **Make component toggles match the headless boundary** - `8dd8f6f` (build)
2. **Remove accidental Linux signing and GUI coupling blockers** - `8dd8f6f` (build)
3. **Stabilize target graph for dry build proof** - `8dd8f6f` (build)

## Files Created/Modified

- `telldus-core/CMakeLists.txt` - Honors `BUILD_LIBTELLDUS-CORE` and guards dependent options.
- `telldus-core/service/CMakeLists.txt` - Makes SignTool required only on Windows.
- `telldus-core/client/CMakeLists.txt` - Makes SignTool required only on Windows.
- `telldus-core/tdtool/CMakeLists.txt` - Links Unix `tdtool` through `${telldus-core_TARGET}`.
- `.planning/phases/01-headless-build-boundary/01-BUILD-BOUNDARY.md` - Updates boundary status and risk notes.

## Decisions Made

- No new CMake option/profile was needed; the existing options are sufficient for the Phase 1 proof command.
- `BUILD_LIBTELLDUS-CORE=FALSE` is explicitly incompatible with the Phase 1 proof because Phase 1 includes both the client library and `tdtool`.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

`cmake` is still not available in the local environment, so source-level assertions were verified and configure proof remains an environment blocker.

## User Setup Required

None.

## Next Phase Readiness

Wave 3 can run or document the configure/dry-build proof. If `cmake` remains unavailable, it should preserve the exact blocker and commit reproducible instructions.

## Self-Check: PASSED

- `rg` checks confirmed `BUILD_LIBTELLDUS-CORE`, `BUILD_TDTOOL`, `BUILD_TDADMIN`, `ENABLE_TESTING`, and expected subdirectory controls.
- `rg -n "Qt|TelldusCenter|telldus-gui" ...` returned no matches for the headless CMake files.
- `git diff --check` passed.

---
*Phase: 01-headless-build-boundary*
*Completed: 2026-05-14*
