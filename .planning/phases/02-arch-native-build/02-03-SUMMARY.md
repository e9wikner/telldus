---
phase: 02-arch-native-build
plan: 03
subsystem: testing
tags: [cppunit, testing, cmake, ctest, headless-ci]

requires:
  - phase: 02-arch-native-build
    plan: 02
    provides: Clean zero-warning build of telldusd, libtelldus-core, and tdtool

provides:
  - Enabled CppUnit test suite running without TellStick hardware
  - Disabled cpplint and cppcheck from CTest for CI-friendly runs
  - Documented unit vs integration test classification
  - Verified all 7 existing CppUnit tests pass on modern Linux

affects:
  - 03-01 (Raspberry Pi portability — same test suite will be used)
  - 07-01 (hardware verification — integration test definitions reserved)
  - All future CI workflows

tech-stack:
  added: []
  patterns:
    - "CppUnit test runner built as TestRunner target via tests/CMakeLists.txt"
    - "Style/static analysis tests disabled from CTest by commenting ADD_SOURCES and cppcheck registrations"
    - "Unit tests exercise pure protocol decode logic with synthetic ControllerMessage data"

key-files:
  created:
    - docs/testing-split.md
  modified:
    - telldus-core/tests/CMakeLists.txt
    - CMakePresets.json

key-decisions:
  - "Tests compiled and passed on first attempt after enabling — no source changes needed, confirming 02-02 warning fixes did not break test compatibility"
  - "Kept ADD_SOURCES function definition and cpplint_filters in tests/CMakeLists.txt for potential future re-enablement"

requirements-completed:
  - NBLD-04

# Metrics
duration: 3min
completed: 2026-05-14
---

# Phase 2 Plan 3: Enable and Run Practical Non-Hardware Tests

**CppUnit tests enabled and passing on headless preset, cpplint/cppcheck disabled from CTest, unit vs integration test split documented**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-14T19:07:23Z
- **Completed:** 2026-05-14T19:10:19Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Enabled CppUnit tests by setting `ENABLE_TESTING TRUE` in `telldus-core/tests/CMakeLists.txt`
- Updated `CMakePresets.json` headless preset to `ENABLE_TESTING: TRUE`
- Removed cpplint and cppcheck CTest registrations from `tests/CMakeLists.txt` while preserving the function definition for future use
- Built `TestRunner` successfully with zero compilation errors
- Verified all 7 CppUnit tests pass: `StringsTest`, `ProtocolEverflourishTest`, `ProtocolHastaTest`, `ProtocolNexaTest`, `ProtocolOregonTest`, `ProtocolSartanoTest`, `ProtocolX10Test`
- Created `docs/testing-split.md` classifying all existing tests as unit tests and reserving integration test categories for Phase 7 hardware verification

## Task Commits

1. **Task 1: Enable CppUnit tests and disable style/static checks** - `83b875e` (feat)
2. **Task 2: Fix test compilation and runtime failures** - No code changes required; tests compiled and passed on first attempt after Task 1
3. **Task 3: Document unit vs integration test split** - `d6b66e0` (docs)

**Plan metadata:** TBD (docs commit after SUMMARY)

## Files Created/Modified

- `telldus-core/tests/CMakeLists.txt` — Enabled `ENABLE_TESTING TRUE`, commented out cpplint `ADD_SOURCES` calls and `cppcheck ADD_TEST`
- `CMakePresets.json` — Updated headless preset `ENABLE_TESTING` from `FALSE` to `TRUE`
- `docs/testing-split.md` — New documentation classifying all 7 CppUnit tests as unit tests with no hardware dependency

## Decisions Made

- Tests compiled and passed without modification, confirming that the 02-02 warning fixes maintained test compatibility
- Preserved `ADD_SOURCES` function and `cpplint_filters` in `tests/CMakeLists.txt` for easy re-enablement of style checks later

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **Ready for 03-01:** Test suite (`TestRunner`, `ctest -R cppunit`) is verified and can be used as the validation gate on Raspberry Pi OS/Debian `aarch64`
- **Ready for 07-01:** Integration test categories (USB detection, device on/off, sensor reception, daemon lifecycle) are documented and reserved
- **Blockers:** None — all headless targets compile cleanly and all unit tests pass

---
*Phase: 02-arch-native-build*
*Completed: 2026-05-14*

## Self-Check: PASSED

- docs/testing-split.md exists
- Commit 83b875e (Task 1) found in git log
- Commit d6b66e0 (Task 3) found in git log
- build/headless/tests/TestRunner exists and is executable
- ctest --test-dir build/headless -R cppunit passes
