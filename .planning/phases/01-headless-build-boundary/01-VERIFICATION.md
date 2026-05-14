---
phase: 01-headless-build-boundary
status: passed
requirements_verified: [NBLD-01]
automated_checks:
  passed: 7
  blocked: 2
  failed: 0
human_verification: []
environment_blockers:
  - cmake is not installed on the local host.
created: 2026-05-14
---

# Phase 1 Verification

## Verdict

Phase 1 passes for the planned headless build boundary goal.

The repository now has a clear Linux-only, GUI-free `telldus-core/` build surface for `telldusd`, `telldus-core`, and `tdtool`. The actual configure and dry-build proof commands could not run on this host because `cmake` is not installed; the exact blocker is recorded in `01-BUILD-BOUNDARY.md` and `telldus-core/README` contains reproducible commands for Phase 2.

## Requirement Traceability

| Requirement | Status | Evidence |
|-------------|--------|----------|
| NBLD-01 | Verified with environment blocker | `telldus-core/` CMake target boundary is explicit and GUI-free; configure proof is blocked only by missing local `cmake`. |

## Must-Haves

| Must-have | Status | Evidence |
|-----------|--------|----------|
| `telldus-core/` remains the build root | PASS | No repo-root `CMakeLists.txt` was added; proof commands use `cmake -S telldus-core`. |
| Boundary includes `telldusd`, `telldus-core`, `tdtool`, and optional tests | PASS | `01-BUILD-BOUNDARY.md` lists all targets and test boundary. |
| Minimal headless dependencies only | PASS | Boundary doc lists CMake, compiler, Threads, libconfuse, libftdi/libusb, and test-only tools. |
| No TelldusCenter/Qt coupling in headless CMake files | PASS | `rg -n "Qt|TelldusCenter|telldus-gui" telldus-core/CMakeLists.txt telldus-core/service/CMakeLists.txt telldus-core/client/CMakeLists.txt telldus-core/tdtool/CMakeLists.txt` returned no matches. |
| Signing is not a Linux configure blocker | PASS | `SignTool` is required only in the `WIN32` branch; Linux uses non-required `FIND_PACKAGE(SignTool)`. |
| Target graph is explicit enough for dry-build proof | PASS | `tdtool` depends on and links through `${telldus-core_TARGET}`. |
| Exact proof commands are committed | PASS | `01-BUILD-BOUNDARY.md` and `telldus-core/README` contain configure and dry-build commands. |
| Dry build proof or exact blocker is recorded | PASS | `01-BUILD-BOUNDARY.md` records `/usr/bin/bash: line 1: cmake: command not found`. |

## Automated Checks

Passed:

- `test -f .planning/phases/01-headless-build-boundary/01-BUILD-BOUNDARY.md`
- `rg -n "Headless Targets|Allowed Dependencies|Excluded Components|Current CMake Controls|Known Boundary Risks|Proof Commands|Local Probe" .planning/phases/01-headless-build-boundary/01-BUILD-BOUNDARY.md`
- `rg -n "BUILD_LIBTELLDUS-CORE|BUILD_TDTOOL|BUILD_TDADMIN|ENABLE_TESTING|ADD_SUBDIRECTORY\\(client|ADD_SUBDIRECTORY\\(tdtool|ADD_SUBDIRECTORY\\(tdadmin" telldus-core/CMakeLists.txt .planning/phases/01-headless-build-boundary/01-BUILD-BOUNDARY.md`
- `rg -n "FIND_PACKAGE\\( *SignTool|SIGN\\(" telldus-core/service/CMakeLists.txt telldus-core/client/CMakeLists.txt telldus-core/tdtool/CMakeLists.txt telldus-core/cmake/FindSignTool.cmake`
- `rg -n "Qt|TelldusCenter|telldus-gui" telldus-core/CMakeLists.txt telldus-core/service/CMakeLists.txt telldus-core/client/CMakeLists.txt telldus-core/tdtool/CMakeLists.txt` returned no matches.
- `rg -n "Proof Result|Dry Build Proof" .planning/phases/01-headless-build-boundary/01-BUILD-BOUNDARY.md`
- `rg -n "HEADLESS LINUX BUILD|FORCE_COMPILE_FROM_TRUNK|FTDI_ENGINE=libftdi" telldus-core/README`

Blocked by local prerequisite:

- `cmake -S telldus-core -B build/telldus-core-headless -DFORCE_COMPILE_FROM_TRUNK=TRUE -DBUILD_TDTOOL=TRUE -DBUILD_TDADMIN=FALSE -DENABLE_TESTING=FALSE -DFTDI_ENGINE=libftdi`
- `cmake --build build/telldus-core-headless --target telldusd telldus-core tdtool -- -n`

First blocker:

```text
/usr/bin/bash: line 1: cmake: command not found
```

## Code Review

Code review status: clean.

Report: `.planning/phases/01-headless-build-boundary/01-REVIEW.md`

## Residual Risk

Modern CMake configure and target graph behavior still need to be executed after installing CMake. Phase 2 should start by installing/confirming Arch build dependencies, then rerun the exact commands from `telldus-core/README`.

## Decision Coverage

All 13 trackable Phase 1 context decisions were covered by plans before execution. Execution honored the relevant boundary decisions:

- `D-01`: `telldus-core/` remains the build root.
- `D-02`: Target boundary includes service, client library, `tdtool`, and optional tests.
- `D-04`: Minimal dependencies are documented.
- `D-06`: No Qt/TelldusCenter dependency is present in the headless CMake files.
- `D-10`: Proof command attempted; exact environment blocker recorded.
- `D-13`: Exact configure/build commands are committed.
