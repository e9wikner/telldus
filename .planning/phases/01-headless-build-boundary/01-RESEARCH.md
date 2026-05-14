# Phase 1: Headless Build Boundary - Research

## Research Complete

**Phase:** 1 - Headless Build Boundary  
**Date:** 2026-05-14  
**Question:** What needs to be known to plan a Linux-only, GUI-free Telldus Core build boundary?

## Executive Summary

The existing repository already has a useful separation: `telldus-core/` is a standalone CMake project and `telldus-gui/` is separate. Phase 1 should keep `telldus-core/` as the build root and focus on making that project clearly configure/dry-build the Linux headless boundary: `telldusd`, `libtelldus-core`, `tdtool`, and the optional test build boundary.

The main risks are not Qt leakage from `telldus-gui/`; they are old CMake assumptions inside `telldus-core/`: unconditional subdirectories, required signing package usage, incomplete component toggles, target-name/linking assumptions, and test wiring that depends on a static service target.

## Current Build Boundary

### Core Entry Point

- `telldus-core/CMakeLists.txt` is the current build root and should remain the Phase 1 entry point.
- It defines version metadata, CMake module path, package options, and subdirectories.
- It unconditionally adds `common`, `service`, `client`, and `tests`.
- `tdtool` is conditional through `BUILD_TDTOOL`.
- `tdadmin` is conditional through `BUILD_TDADMIN`, defaulting true on non-Windows/non-Apple systems.

### Headless Targets

- `telldus-core/service/CMakeLists.txt` builds `telldusd` on Linux.
- `telldus-core/client/CMakeLists.txt` builds the shared C API library `telldus-core` on Linux.
- `telldus-core/tdtool/CMakeLists.txt` builds `tdtool`.
- `telldus-core/tests/CMakeLists.txt` defines optional CppUnit/cpplint/cppcheck tests behind `ENABLE_TESTING`.

### GUI Boundary

- `telldus-gui/` is a separate CMake project and is not pulled from `telldus-core/CMakeLists.txt`.
- Phase 1 does not need to touch `telldus-gui/` unless a documentation note is needed to clarify it is outside the headless build.

## Dependency Findings

### Minimal Headless Dependencies

Phase 1 should plan around these allowed dependencies:

- CMake
- C and C++ compiler toolchain
- pthreads / `Threads`
- libconfuse for Linux settings parsing
- libftdi/libusb stack for Linux TellStick hardware I/O
- CppUnit, Python, cpplint script, and cppcheck only when tests are enabled

### Signing Package

`telldus-core/service/CMakeLists.txt` and `telldus-core/client/CMakeLists.txt` both call `FIND_PACKAGE(SignTool REQUIRED)`, and `tdtool` calls `SIGN(tdtool)`. `telldus-core/cmake/FindSignTool.cmake` defines `SIGN()` as a no-op on non-Windows, but because `FIND_PACKAGE(... REQUIRED)` is still used from service/client, this remains a configure-time risk if the module is not found or if CMake package semantics are stricter than expected.

Planning implication: make signing explicitly non-blocking/no-op for Linux headless builds while preserving Windows signing behavior behind guards.

### FTDI Backend

Linux defaults to `FTDI_ENGINE=libftdi` in `telldus-core/service/CMakeLists.txt`.

- libftdi path:
  - `FIND_LIBRARY(FTDI_LIBRARY ftdi1)`
  - `INCLUDE(FindPkgConfig)`
  - `PKG_SEARCH_MODULE(FTDI libftdi)`
  - adds `TellStick_libftdi.cpp`
- ftd2xx path:
  - `FIND_LIBRARY(FTD2XX_LIBRARY ftd2xx)`
  - adds `TellStick_ftd2xx.cpp`

Planning implication: keep libftdi as the Linux v1 supported/default path. Do not spend Phase 1 effort preserving ftd2xx unless it remains harmless.

### Test Dependencies

Tests are opt-in but should be included in the build boundary. Current test wiring:

- `ENABLE_TESTING` defaults false in `telldus-core/tests/CMakeLists.txt`.
- When enabled, tests expect CppUnit, Python, and cppcheck.
- `telldus-core/tests/service/CMakeLists.txt` links `TelldusServiceTests` against `TelldusServiceStatic`.
- `TelldusServiceStatic` is only defined at the bottom of `telldus-core/service/CMakeLists.txt` when `ENABLE_TESTING` is enabled.

Planning implication: tests may fail due to target ordering, target naming, missing dependencies, or modern compiler issues. Phase 1 should prove the test build boundary can at least configure or explicitly document/fix boundary blockers; full test execution belongs mainly to Phase 2.

## Probe Findings

A local configure probe was attempted:

```bash
cmake -S telldus-core -B /tmp/telldus-core-phase1-probe \
  -DFORCE_COMPILE_FROM_TRUNK=TRUE \
  -DBUILD_TDTOOL=TRUE \
  -DBUILD_TDADMIN=FALSE \
  -DENABLE_TESTING=FALSE \
  -DFTDI_ENGINE=libftdi
```

The probe failed immediately because `cmake` is not installed in the current environment:

```text
/usr/bin/bash: line 1: cmake: command not found
```

Available locally:

- `/usr/bin/gcc`
- `/usr/bin/g++`
- `/usr/bin/pkg-config`

Planning implication: Phase 1 must start with dependency discovery/documentation. The dry build proof cannot be completed until CMake is installed or a container proof is used.

## Likely Phase 1 Work Items

### Build Surface Audit

Inspect and document the exact headless target set:

- `telldusd`
- `telldus-core` shared library
- `tdtool`
- optional test targets when `ENABLE_TESTING=TRUE`

### CMake Boundary Fixes

Likely fixes to plan:

- Honor or remove ambiguity around `BUILD_LIBTELLDUS-CORE`.
- Ensure `BUILD_TDTOOL`, `BUILD_TDADMIN`, and `ENABLE_TESTING` are enough to express the v1 boundary.
- Keep `BUILD_TDADMIN=FALSE` for the Phase 1 proof unless admin support is necessary for headless build correctness.
- Make signing no-op/optional for Linux headless builds without breaking Windows behavior.
- Ensure `tdtool` links to the target library rather than a hard-coded build artifact path if that blocks configure/build clarity.
- Keep non-Linux source logic guarded, not modernized or deleted.

### Documentation Boundary

Phase 1 must produce committed docs/build instructions. The likely instruction target should include:

- Arch dependency list, starting with CMake and compiler prerequisites.
- Example configure command from `telldus-core/`.
- Example dry build command for expected targets.
- Notes that `telldus-gui/`, bindings, examples, Docker runtime, Raspberry Pi portability, config compatibility validation, and hardware validation are out of Phase 1.

## Validation Architecture

### Automated Validation Targets

Phase 1 validation should be based on build-system commands rather than hardware:

1. CMake configure command from repo root using `telldus-core` as source:

```bash
cmake -S telldus-core -B build/telldus-core-headless \
  -DFORCE_COMPILE_FROM_TRUNK=TRUE \
  -DBUILD_TDTOOL=TRUE \
  -DBUILD_TDADMIN=FALSE \
  -DENABLE_TESTING=FALSE \
  -DFTDI_ENGINE=libftdi
```

2. Dry build / target graph proof:

```bash
cmake --build build/telldus-core-headless --target telldusd telldus-core tdtool -- -n
```

If `-- -n` is not supported by the generated backend, use the closest non-destructive target-list/build-start proof available for that generator.

3. Optional test boundary configure:

```bash
cmake -S telldus-core -B build/telldus-core-headless-tests \
  -DFORCE_COMPILE_FROM_TRUNK=TRUE \
  -DBUILD_TDTOOL=TRUE \
  -DBUILD_TDADMIN=FALSE \
  -DENABLE_TESTING=TRUE \
  -DFTDI_ENGINE=libftdi
```

### Manual Validation

- Confirm no Qt/TelldusCenter dependencies are required for the headless configure path.
- Confirm any ftd2xx support is either untouched/harmless or explicitly outside Linux v1.
- Confirm documentation contains exact commands that Phase 2 can reproduce.

### Known Initial Blocker

The current environment lacks `cmake`. Plan tasks should account for this before requiring a dry build proof.

## Recommendations for Planning

1. Split Phase 1 into three plans:
   - audit and document the build boundary,
   - apply minimal CMake/build-surface fixes,
   - produce proof commands and committed docs.
2. Keep source changes scoped to `telldus-core/CMakeLists.txt`, `telldus-core/service/CMakeLists.txt`, `telldus-core/client/CMakeLists.txt`, `telldus-core/tdtool/CMakeLists.txt`, `telldus-core/tests/CMakeLists.txt`, and documentation.
3. Do not touch `telldus-gui/`, bindings, examples, MQTT, Docker runtime, or Raspberry Pi-specific support in Phase 1.
4. Treat missing local CMake as an environment prerequisite, not a source-code failure.

## Risks

- Modern CMake may reject old policy/version declarations or target properties in ways not visible until CMake is installed.
- `FIND_PACKAGE(SignTool REQUIRED)` could remain an unnecessary configure blocker for Linux.
- `tdtool` hard-coded library path may make target dependency clarity weaker than desired.
- `ENABLE_TESTING=TRUE` may expose test-only target or dependency issues that are properly Phase 2 unless they block the boundary.
