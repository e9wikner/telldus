# Phase 3: Raspberry Pi Portability — Build Verification Results

**Date:** 2026-05-14
**Verification Method:** Docker multi-arch build with QEMU user-mode emulation (`--platform linux/arm64`)
**Base Image:** `debian:bookworm-slim`
**Build Configuration:** Headless CMake preset (architecture-agnostic), `FTDI_ENGINE=libftdi`

---

## Artifact Scope Verification

The following binaries were built and verified inside a `debian:bookworm-slim linux/arm64` container:

| Binary | Type | Status |
|--------|------|--------|
| `telldusd` | Daemon executable | Built and verified |
| `libtelldus-core.so.2.1.3` | Shared C API library | Built and verified |
| `tdtool` | CLI utility | Built and verified |
| `TestRunner` | CppUnit test runner | Built and verified |

**Scope Comparison:**
The aarch64 artifact set matches the Arch build v1 scope exactly. Phase 2 (Arch Native Build) produced `telldusd`, `libtelldus-core.so`, `tdtool`, and `TestRunner`. The Debian aarch64 build produces the same four artifacts with zero source code modifications.

---

## Architecture Verification

The `file` command was run on each built binary inside the `linux/arm64` container to confirm genuine ARM aarch64 ELF format:

```
build/headless/service/telldusd:
ELF 64-bit LSB pie executable, ARM aarch64, version 1 (GNU/Linux), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, BuildID[sha1]=442d2f2118c4221e81a8b5224aa96349ad740bc2, for GNU/Linux 3.7.0, not stripped

build/headless/client/libtelldus-core.so.2.1.3:
ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, BuildID[sha1]=0da794452faafd0370fedb7fdbe16dac99a98038, not stripped

build/headless/tdtool/tdtool:
ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, BuildID[sha1]=0d61c056615e08ee32e11f9c42b3365fc84c178d, for GNU/Linux 3.7.0, not stripped
```

All three binaries are confirmed as **ARM aarch64** ELF format.

---

## Test Results

CppUnit tests were executed via `ctest --test-dir build/headless -R cppunit --output-on-failure` inside the aarch64 container:

- **Result:** 100% tests passed (1/1 test suites, 7/7 individual tests)
- **Test suites:** StringsTest, ProtocolEverflourishTest, ProtocolHastaTest, ProtocolNexaTest, ProtocolOregonTest, ProtocolSartanoTest, ProtocolX10Test
- **Hardware dependency:** None — all tests are unit tests exercising pure protocol decode logic with synthetic data

---

## Build Configuration Notes

- CMake preset: Reused existing `headless` preset unchanged (architecture-agnostic)
- Dependencies: `cmake`, `build-essential`, `pkg-config`, `libftdi1-dev`, `libconfuse-dev`, `libusb-1.0-0-dev`, `libcppunit-dev`
- Build flag: `FORCE_COMPILE_FROM_TRUNK=TRUE` required by `telldus-core/CMakeLists.txt`
- FTDI backend: `libftdi` (CMake `FIND_LIBRARY(FTDI_LIBRARY ftdi1)`)

---

## Issues Found

**QEMU User-Mode Emulation Instability:**

Parallel compilation (`cmake --build build/headless --parallel $(nproc)`) under QEMU user-mode emulation for aarch64 intermittently triggers compiler segfaults (Error 139 / SIGSEGV). The segfaults occur on different source files across attempts (e.g., `Sensor.cpp.o`, `ProtocolIkea.cpp.o`, `Mutex.cpp.o`), confirming this is QEMU environmental instability rather than a code defect.

**Mitigation:** Single-threaded builds (`--parallel 1`) are required for reliable compilation under QEMU aarch64 emulation. The same codebase compiles successfully with parallel builds on native aarch64 (verified independently) and on native amd64.

**No architecture-specific code issues were found.** The codebase contains no `#ifdef __aarch64__` or endianness-specific logic in the Linux code path. The only platform preprocessor branches are `#ifdef _LINUX`, `#ifdef _WINDOWS`, and `#ifdef _MACOSX`.

---

## Scope Boundary

This document covers **build verification only** — confirming that the headless Telldus Core components compile, link, pass unit tests, and produce genuine ARM aarch64 binaries on Debian Bookworm.

**Runtime and hardware validation** (TellStick Duo USB detection, device on/off commands, dimming, sensor reception, daemon lifecycle) belongs to **Phase 7: TellStick Duo Hardware Verification**.

**Docker runtime image creation** with `/etc/tellstick.conf` bind-mount support belongs to **Phase 5: Docker Image and Config Mount**.

---

*Phase 3 complete. Ready for Phase 4: Config Compatibility.*
