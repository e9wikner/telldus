# Phase 1 Headless Build Boundary

## Headless Targets

Phase 1 uses `telldus-core/` as the build root.

The Linux headless boundary contains exactly:

- `telldusd` from `telldus-core/service/CMakeLists.txt`.
- `telldus-core` from `telldus-core/client/CMakeLists.txt`.
- `tdtool` from `telldus-core/tdtool/CMakeLists.txt` when `BUILD_TDTOOL=TRUE`.
- Optional `TestRunner` and test targets when `ENABLE_TESTING=TRUE`.

The boundary includes the test build surface so later phases can compile and run tests, but Phase 1 does not need to make the full test suite pass.

## Allowed Dependencies

The Phase 1 Linux headless dependency boundary is:

- CMake.
- C and C++ compiler toolchain.
- pthreads through CMake `Threads`.
- `libconfuse` for Linux `/etc/tellstick.conf` parsing.
- `libftdi` and its `libusb` stack for TellStick hardware I/O.
- `CppUnit`, Python, `cpplint.py`, and `cppcheck` only when `ENABLE_TESTING=TRUE`.

Linux v1 should prefer `FTDI_ENGINE=libftdi`. The `ftd2xx` path may remain if it does not complicate the Linux headless build.

## Excluded Components

The following are outside Phase 1:

- `telldus-gui/`.
- TelldusCenter.
- Qt GUI dependencies.
- bindings.
- examples.
- Docker runtime.
- Raspberry Pi portability.
- hardware validation.
- MQTT.
- Home Assistant integration.

## Current CMake Controls

Current build controls observed in `telldus-core/CMakeLists.txt` and subdirectories:

- `FORCE_COMPILE_FROM_TRUNK=TRUE` is required to configure from this source tree.
- `BUILD_TDTOOL` controls whether `telldus-core/tdtool` is added.
- `BUILD_TDADMIN` controls whether `telldus-core/tdadmin` is added; the current Linux default is `TRUE`.
- `BUILD_LIBTELLDUS-CORE` controls whether `telldus-core/client` is added. `BUILD_TDTOOL=TRUE` and `ENABLE_TESTING=TRUE` require it because both need the client library target.
- `ENABLE_TESTING` is defined in `telldus-core/tests/CMakeLists.txt` and defaults to `FALSE`.
- `FTDI_ENGINE` defaults to `libftdi` on Linux and selects either `TellStick_libftdi.cpp` or `TellStick_ftd2xx.cpp`.
- `GENERATE_MAN` and `GENERATE_DOXYGEN` are optional documentation/manpage controls.

Current target names:

- Linux service target: `telldusd`.
- Linux client library target: `telldus-core`.
- CLI target: `tdtool`.
- Optional test runner target: `TestRunner`.

## Known Boundary Risks

- `telldus-core/CMakeLists.txt` unconditionally adds `common`, `service`, and `tests`; `client`, `tdtool`, and `tdadmin` are option-controlled.
- `BUILD_LIBTELLDUS-CORE=FALSE` is outside the Phase 1 proof command because the boundary includes the `telldus-core` client library and `tdtool`.
- `BUILD_TDADMIN` defaults to `TRUE` on Linux; Phase 1 proof commands should pass `-DBUILD_TDADMIN=FALSE` to avoid admin tooling in the headless proof.
- `SignTool` is required only on Windows. Linux still loads `FindSignTool.cmake` so `SIGN()` remains defined as a no-op.
- `tdtool` links through `${telldus-core_TARGET}` so the target graph stays explicit.
- `ENABLE_TESTING=TRUE` depends on `TelldusServiceStatic`, CppUnit, Python, and cppcheck, so test-boundary configure/build can expose extra issues that belong mainly to Phase 2 unless they block target selection.
- This boundary intentionally does not validate the TellStick Duo, `/etc/tellstick.conf` runtime compatibility, Docker USB passthrough, MQTT, or Home Assistant integration.

## Proof Commands

Primary Linux headless configure proof from the repository root:

```bash
cmake -S telldus-core -B build/telldus-core-headless \
  -DFORCE_COMPILE_FROM_TRUNK=TRUE \
  -DBUILD_TDTOOL=TRUE \
  -DBUILD_TDADMIN=FALSE \
  -DENABLE_TESTING=FALSE \
  -DFTDI_ENGINE=libftdi
```

Dry build or target-graph proof:

```bash
cmake --build build/telldus-core-headless --target telldusd telldus-core tdtool -- -n
```

Optional test-boundary configure proof:

```bash
cmake -S telldus-core -B build/telldus-core-headless-tests \
  -DFORCE_COMPILE_FROM_TRUNK=TRUE \
  -DBUILD_TDTOOL=TRUE \
  -DBUILD_TDADMIN=FALSE \
  -DENABLE_TESTING=TRUE \
  -DFTDI_ENGINE=libftdi
```

## Local Probe

Planning found these local tools:

- `/usr/bin/gcc`
- `/usr/bin/g++`
- `/usr/bin/pkg-config`

Planning also found that `cmake` was not found in this environment. The attempted configure command was:

```bash
cmake -S telldus-core -B /tmp/telldus-core-phase1-probe \
  -DFORCE_COMPILE_FROM_TRUNK=TRUE \
  -DBUILD_TDTOOL=TRUE \
  -DBUILD_TDADMIN=FALSE \
  -DENABLE_TESTING=FALSE \
  -DFTDI_ENGINE=libftdi
```

It failed with:

```text
/usr/bin/bash: line 1: cmake: command not found
```

## Proof Result

Phase 1 attempted the headless configure proof from the repository root after the CMake boundary changes:

```bash
cmake -S telldus-core -B build/telldus-core-headless \
  -DFORCE_COMPILE_FROM_TRUNK=TRUE \
  -DBUILD_TDTOOL=TRUE \
  -DBUILD_TDADMIN=FALSE \
  -DENABLE_TESTING=FALSE \
  -DFTDI_ENGINE=libftdi
```

Result:

```text
/usr/bin/bash: line 1: cmake: command not found
```

Status: Configure proof is blocked by the local environment prerequisite `cmake`, not by a source-code failure observed in this phase.

## Dry Build Proof

The intended dry build or target-graph proof is:

```bash
cmake --build build/telldus-core-headless --target telldusd telldus-core tdtool -- -n
```

Targets covered by this proof:

- `telldusd`
- `telldus-core`
- `tdtool`

Status: Dry build proof is blocked until the configure proof creates `build/telldus-core-headless`. The first blocker is still `cmake: command not found`.
