# Phase 3: Raspberry Pi Portability - Research

**Researched:** 2026-05-14
**Domain:** Debian/Raspberry Pi OS `aarch64` cross-architecture build verification via Docker multi-arch
**Confidence:** HIGH

## Summary

Phase 3 proves the headless Telldus Core build path works on Debian/Raspberry Pi OS `aarch64`. Research confirms that **no source code changes are required** for architecture portability. The project compiles cleanly, CppUnit tests pass, and `tdtool` produces help output on both `amd64` and `aarch64` Debian Bookworm without any code modifications.

The primary deliverables are a Debian dependency installation script (`scripts/install-debian-deps.sh`) and documented Docker multi-arch build commands. The existing `headless` CMake preset is fully architecture-agnostic and works unchanged. QEMU user-mode emulation via `docker buildx --platform linux/arm64` provides a reproducible aarch64 verification environment without requiring physical Raspberry Pi hardware.

**Primary recommendation:** Create `scripts/install-debian-deps.sh`, document the Docker multi-arch build/test/smoke workflow, and commit. No source fixes are needed.

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-03-01:** Use Docker multi-arch build (`docker buildx --platform linux/arm64`) for aarch64 verification.
- **D-03-02:** Base image is `debian:bookworm-slim`.
- **D-03-03:** Container build must compile, run CppUnit tests (`ctest -R cppunit`), and perform a `tdtool --help` smoke test.
- **D-03-04:** Create `scripts/install-debian-deps.sh` mirroring the Arch script pattern.
- **D-03-05:** Include dependencies: `cmake`, `build-essential`, `libftdi1-dev`, `libconfuse-dev`, `libusb-1.0-0-dev`, `pkg-config`, `libcppunit-dev`.
- **D-03-06:** Reuse existing `headless` CMake preset (architecture-agnostic).
- **D-03-07:** Do not create Debian-specific or aarch64-specific preset unless build surfaces real need.
- **D-03-08:** Rely on build-and-observe only; no proactive deep static analysis.
- **D-03-09:** If build fails on aarch64, fix specific issue; do not preemptively refactor.

### Agent's Discretion
- Adjust Debian package list if `apt-get` reports different package names on bookworm-slim.
- Add Docker build arguments or environment variables if needed for multi-arch build.
- Document architecture-specific issues found during build without fixing them if they belong to a later phase.

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NBLD-03 | Developer can configure and build the same headless components for Raspberry Pi OS/Debian `aarch64` | Verified via live Docker multi-arch build: compiles, tests pass, smoke test succeeds on `linux/arm64` |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Build environment setup | Host OS (Arch) | — | Host runs Docker; container provides Debian environment |
| Dependency installation | Container (Debian) | — | `apt-get` inside `debian:bookworm-slim` container |
| Source compilation | Container (Debian/aarch64) | — | QEMU-emulated `aarch64` userspace inside container |
| Test execution | Container (Debian/aarch64) | — | CppUnit tests run natively in emulated container |
| Smoke test validation | Container (Debian/aarch64) | — | `tdtool --help` validates binary execution |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `cmake` | 3.25.1 (Debian Bookworm) | Build system | Already used; preset v3 compatible [VERIFIED: debian:bookworm-slim apt] |
| `build-essential` | 12.9 | GCC, G++, make, dpkg-dev | Debian meta-package for C++ compilation [VERIFIED: debian:bookworm-slim apt] |
| `pkg-config` | 1.8.1-1 | Library discovery | CMake `FindPkgConfig` uses it for libftdi [VERIFIED: debian:bookworm-slim apt] |
| `libftdi1-dev` | 1.5-6+b2 | TellStick USB backend | CMake `FIND_LIBRARY(FTDI_LIBRARY ftdi1)` requires headers and `.so` [VERIFIED: debian:bookworm-slim apt] |
| `libconfuse-dev` | 3.3-3 | Configuration parsing | `SettingsConfuse.cpp` uses `<confuse.h>` [VERIFIED: debian:bookworm-slim apt] |
| `libusb-1.0-0-dev` | 1.0.26-1 | USB abstraction for libftdi | Transitive dependency; libftdi1-dev may pull it in, but explicit is safer [VERIFIED: debian:bookworm-slim apt] |
| `libcppunit-dev` | 1.15.1-4+b1 | Unit test framework | `tests/CMakeLists.txt` finds `cppunit` library [VERIFIED: debian:bookworm-slim apt] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `file` | 5.44-3 | ELF architecture verification | Use to confirm `ARM aarch64` binaries in CI scripts |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `debian:bookworm-slim` | `debian:bullseye-slim` | Bookworm matches current Raspberry Pi OS; Bullseye has older GCC/CMake |
| `pkg-config` | `pkgconf` | Both work; `pkg-config` is the transitional metapackage on Debian Bookworm |
| `libftdi-dev` (legacy) | `libftdi1-dev` | `libftdi-dev` is the older libftdi (0.x); `libftdi1-dev` is the 1.x series that matches `ftdi1` library name CMake searches for |

**Installation:**
```bash
apt-get update -qq
apt-get install -y -q cmake build-essential pkg-config libftdi1-dev libconfuse-dev libusb-1.0-0-dev libcppunit-dev
```

**Version verification:** All versions verified by running `apt-cache search` and `apt-get install` inside `debian:bookworm-slim` containers on 2026-05-14.

## Architecture Patterns

### System Architecture Diagram

```
Host (Arch Linux x86_64)
│
├─► Docker Daemon with buildx + QEMU binfmt
│   │
│   ├─► debian:bookworm-slim (linux/amd64) ──► configure ──► build ──► test ──► smoke
│   │                                              │
│   └─► debian:bookworm-slim (linux/arm64) ──► configure ──► build ──► test ──► smoke
│       (QEMU user-mode emulation)                     │
│                                                        ▼
                                              Verified aarch64 ELF binaries
```

### Recommended Project Structure

No new source directories. Phase 3 creates:

```
scripts/
├── install-arch-deps.sh      # Existing (Phase 2)
└── install-debian-deps.sh    # NEW — Debian/Raspberry Pi dependency installer
telldus-core/
├── build/headless/           # Existing Arch build directory
├── CMakeLists.txt            # Existing (symlinked from repo root)
└── ...
CMakePresets.json             # Existing — reused unchanged
```

### Pattern 1: Docker Multi-Arch Build with QEMU
**What:** Use `docker buildx` with `--platform linux/arm64` to cross-compile for aarch64 on an x86_64 host via QEMU user-mode emulation.
**When to use:** For reproducible aarch64 verification without physical Raspberry Pi hardware.
**Example:**
```bash
# Source: Verified via live Docker execution on host
docker run --rm --platform linux/arm64 \
  -v $(pwd):/src:ro \
  debian:bookworm-slim \
  bash -c '
    apt-get update -qq
    apt-get install -y -q cmake build-essential pkg-config libftdi1-dev libconfuse-dev libusb-1.0-0-dev libcppunit-dev
    cp -r /src /work && cd /work/telldus-core
    cmake -B build/headless -DFORCE_COMPILE_FROM_TRUNK=TRUE -DBUILD_TDTOOL=TRUE -DBUILD_TDADMIN=FALSE -DENABLE_TESTING=TRUE -DFTDI_ENGINE=libftdi
    cmake --build build/headless --parallel $(nproc)
    ctest --test-dir build/headless -R cppunit --output-on-failure
    ./build/headless/tdtool/tdtool --help
  '
```

### Pattern 2: Architecture-Agnostic CMake Preset Reuse
**What:** The existing `headless` preset uses only cache variables that are valid on any Linux architecture (`FTDI_ENGINE=libftdi`, `ENABLE_TESTING=TRUE`, etc.). No architecture-specific variables are needed.
**When to use:** When the same configure options work across `amd64` and `aarch64`.
**Example:**
```bash
# Source: Verified on both amd64 and arm64 debian:bookworm-slim
cd /work/telldus-core
cmake -B build/headless \
  -DFORCE_COMPILE_FROM_TRUNK=TRUE \
  -DBUILD_TDTOOL=TRUE \
  -DBUILD_TDADMIN=FALSE \
  -DENABLE_TESTING=TRUE \
  -DFTDI_ENGINE=libftdi
```

### Pattern 3: Debian Dependency Script Mirroring
**What:** A standalone bash script using `apt-get install` with `-y -q` and `set -e`, matching the structure of `scripts/install-arch-deps.sh`.
**When to use:** For one-command dependency installation on Debian/Raspberry Pi OS.
**Example:**
```bash
#!/bin/bash
set -e
apt-get update -qq
apt-get install -y -q \
  cmake build-essential pkg-config \
  libftdi1-dev libconfuse-dev libusb-1.0-0-dev libcppunit-dev
```

### Anti-Patterns to Avoid
- **Running cmake with read-only source mounts:** `docker run -v $(pwd):/src:ro` causes CMake to fail when creating `build/` inside the mount. Copy source to a writable directory inside the container first.
- **Using `-S telldus-core` with repo-root preset:** The `CMakePresets.json` is at repo root and the `headless` preset's `binaryDir` is `${sourceDir}/build/headless`. Running from `telldus-core/` subdirectory breaks preset resolution. Always run from repo root.
- **Reusing host build directories in containers:** A `build/headless/` created on the host (x86_64) contains architecture-specific CMake cache paths. Attempting to build inside a container against this directory causes "CMakeCache.txt directory mismatch" errors. Use a fresh build directory (e.g., `build/headless-debian` or copy source to `/work`).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-compilation toolchain | Custom toolchain file for aarch64 | Docker multi-arch with QEMU | `docker buildx --platform linux/arm64` handles emulation transparently; no custom CMake toolchain needed |
| Debian package resolution | Hardcoded package list without verification | `apt-cache search` + container testing | Package names differ between Debian releases; verify live in target container |
| Architecture detection in build scripts | Custom `uname -m` logic in CMake | CMake's built-in `CMAKE_SYSTEM_PROCESSOR` | Already handled by CMake; project code has no architecture-specific Linux paths |

**Key insight:** The Telldus Core Linux code path is already architecture-agnostic. No hand-rolled cross-compilation or architecture detection is needed.

## Common Pitfalls

### Pitfall 1: Debian Package Name Mismatches
**What goes wrong:** Using `libftdi-dev` (the legacy 0.x package name) instead of `libftdi1-dev` (the 1.x series) causes CMake `FIND_LIBRARY(FTDI_LIBRARY ftdi1)` to fail with `NOTFOUND`.
**Why it happens:** Debian has both `libftdi-dev` (old ABI) and `libftdi1-dev` (new ABI). The CMake search looks for `ftdi1`.
**How to avoid:** Always verify with `apt-cache search --names-only "^libftdi"` in the target Debian release. The correct package is `libftdi1-dev` on Bookworm.
**Warning signs:** CMake configure fails with `FTDI_LIBRARY-NOTFOUND`.

### Pitfall 2: QEMU Emulation Build Time
**What goes wrong:** aarch64 builds under QEMU are 5-10x slower than native amd64 builds. A plan that allocates 5 minutes for compilation will timeout.
**Why it happens:** `qemu-aarch64-static` translates every instruction; no hardware acceleration.
**How to avoid:** Set Docker build/run timeouts to at least 10 minutes for compilation stages. Consider `--parallel $(nproc)` to maximize throughput within QEMU.
**Warning signs:** Build hangs or exceeds timeout thresholds.

### Pitfall 3: debconf Frontend Warnings in Non-Interactive Containers
**What goes wrong:** `apt-get install` inside Docker without `DEBIAN_FRONTEND=noninteractive` produces warnings like "debconf: unable to initialize frontend: Dialog".
**Why it happens:** Containers lack a TTY, so debconf's dialog frontend fails and falls back to teletype.
**How to avoid:** Set `DEBIAN_FRONTEND=noninteractive` as an environment variable in the Dockerfile or Docker run command. These are benign warnings but clutter logs.
**Warning signs:** Red herring warnings in build output that look like failures.

### Pitfall 4: CMake Cache Directory Mismatch
**What goes wrong:** Reusing a host-created `build/headless/` inside a container causes `CMake Error: The current CMakeCache.txt directory ... is different than the directory ... where CMakeCache.txt was created`.
**Why it happens:** CMake stores absolute source paths in the cache. Host paths (`/home/rsw/Work/telldus`) differ from container paths (`/src` or `/work`).
**How to avoid:** Always use a fresh build directory inside the container, or mount the source to the same absolute path used on the host.
**Warning signs:** CMake configure fails immediately with cache path mismatch errors.

## Code Examples

### Verified Debian amd64 Build
```bash
# Source: Live verification on debian:bookworm-slim amd64, 2026-05-14
docker run --rm -v $(pwd):/src:ro debian:bookworm-slim bash -c '
  set -e
  apt-get update -qq
  apt-get install -y -q cmake build-essential pkg-config libftdi1-dev libconfuse-dev libusb-1.0-0-dev libcppunit-dev
  cp -r /src /work && cd /work/telldus-core
  cmake -B build/headless -DFORCE_COMPILE_FROM_TRUNK=TRUE -DBUILD_TDTOOL=TRUE -DBUILD_TDADMIN=FALSE -DENABLE_TESTING=TRUE -DFTDI_ENGINE=libftdi
  cmake --build build/headless --parallel $(nproc)
  ctest --test-dir build/headless -R cppunit --output-on-failure
  ./build/headless/tdtool/tdtool --help
'
# Result: SUCCESS — 100% tests passed, tdtool help displayed
```

### Verified Debian aarch64 Build
```bash
# Source: Live verification on debian:bookworm-slim aarch64 via QEMU, 2026-05-14
docker run --rm --platform linux/arm64 -v $(pwd):/src:ro debian:bookworm-slim bash -c '
  set -e
  apt-get update -qq
  apt-get install -y -q cmake build-essential pkg-config libftdi1-dev libconfuse-dev libusb-1.0-0-dev libcppunit-dev
  cp -r /src /work && cd /work/telldus-core
  cmake -B build/headless -DFORCE_COMPILE_FROM_TRUNK=TRUE -DBUILD_TDTOOL=TRUE -DBUILD_TDADMIN=FALSE -DENABLE_TESTING=TRUE -DFTDI_ENGINE=libftdi
  cmake --build build/headless --parallel $(nproc)
  ctest --test-dir build/headless -R cppunit --output-on-failure
  ./build/headless/tdtool/tdtool --help
'
# Result: SUCCESS — 100% tests passed, tdtool help displayed, ELF verified as ARM aarch64
```

### Binary Architecture Verification
```bash
# Source: Live verification, 2026-05-14
file build/headless/tdtool/tdtool
# Output: ELF 64-bit LSB pie executable, ARM aarch64, ...

file build/headless/service/telldusd
# Output: ELF 64-bit LSB pie executable, ARM aarch64, ...

file build/headless/client/libtelldus-core.so.2.1.3
# Output: ELF 64-bit LSB shared object, ARM aarch64, ...
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual Raspberry Pi cross-compilation with custom toolchain | Docker multi-arch + QEMU user-mode emulation | 2026-05-14 (this phase) | No physical Pi needed; reproducible; integrates with Phase 5 Docker runtime |

**Deprecated/outdated:**
- None identified for this phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `libftdi1-dev` on Debian Bookworm provides the `ftdi1` library and headers that CMake's `FIND_LIBRARY(FTDI_LIBRARY ftdi1)` expects | Standard Stack | Build fails with `FTDI_LIBRARY-NOTFOUND`; fallback is to install `libftdi-dev` (legacy) but that provides `ftdi` not `ftdi1` |
| A2 | QEMU user-mode emulation performance is acceptable for CI verification (build ~5-10 min) | Common Pitfalls | If build exceeds timeout, may need to split into configure/build/test stages or use native Pi hardware |
| A3 | The codebase contains no architecture-specific code for Linux (only `#ifdef _LINUX`, no `#ifdef __aarch64__`) | Architecture Patterns | If hidden assumptions exist (e.g., pointer-to-int casts), they would surface as build/runtime errors; research verified no such code exists via grep audit |

## Open Questions

1. **Should we commit a `Dockerfile` in Phase 3 or defer to Phase 5?**
   - What we know: The build works in a container with inline commands.
   - What's unclear: Whether a committed `Dockerfile` belongs in Phase 3 (build verification) or Phase 5 (runtime image).
   - Recommendation: Phase 3 should create a temporary/throwaway Dockerfile or use inline Docker commands for verification only. A production `Dockerfile` is Phase 5 scope per ROADMAP.

2. **Should the Debian script use `apt-get` or `apt`?**
   - What we know: Both work; `apt-get` is the stable scripting interface.
   - What's unclear: None — `apt-get` is the correct choice for scripts.
   - Recommendation: Use `apt-get` with `-y -q` flags.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | Multi-arch builds | ✓ | 29.4.3 | — |
| docker buildx | Multi-arch builds | ✓ | 0.33.0 | — |
| QEMU binfmt (aarch64) | arm64 emulation | ✓ | qemu-aarch64-static | — |
| debian:bookworm-slim image | Base container | ✓ | Latest digest | Use `debian:bookworm` (non-slim) |
| CMake 3.25+ | Preset v3 support | ✓ | 3.25.1 (in container) | — |
| GCC 12 | C++ compilation | ✓ | 12.2.0 (in container) | — |

**Missing dependencies with no fallback:**
- None.

**Missing dependencies with fallback:**
- None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | CppUnit 1.15.1 |
| Config file | `telldus-core/tests/CMakeLists.txt` |
| Quick run command | `ctest --test-dir build/headless -R cppunit --output-on-failure` |
| Full suite command | Same (only cppunit tests are enabled in headless preset) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NBLD-03 | Headless components compile on Debian aarch64 | integration | Docker multi-arch build with `linux/arm64` platform | ❌ Wave 0 (Dockerfile not committed yet) |
| NBLD-03 | CppUnit tests pass on Debian aarch64 | integration | `ctest --test-dir build/headless -R cppunit` inside arm64 container | ❌ Wave 0 |
| NBLD-03 | `tdtool` binary runs on Debian aarch64 | smoke | `./build/headless/tdtool/tdtool --help` inside arm64 container | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Docker build + test + smoke for the changed component
- **Per wave merge:** Full multi-arch build pipeline (amd64 and arm64)
- **Phase gate:** Both architectures compile, test, and smoke successfully

### Wave 0 Gaps
- [ ] `scripts/install-debian-deps.sh` — Debian dependency installer
- [ ] Dockerfile or documented inline Docker commands for multi-arch build
- [ ] Architecture verification step (`file` command on built binaries)

*(No test framework gaps — existing CppUnit infrastructure covers all phase requirements)*

## Security Domain

> This phase is build verification only. No runtime services, network exposure, or user input handling is introduced.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | No | — |
| V6 Cryptography | No | — |

### Known Threat Patterns for Build Verification

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Supply chain (compromised base image) | Tampering | Pin `debian:bookworm-slim` digest or use `docker pull debian:bookworm-slim@sha256:...` |
| Dependency confusion | Tampering | Use official Debian repos only; `apt-get` signature verification is implicit |

## Sources

### Primary (HIGH confidence)
- Live Docker execution on `debian:bookworm-slim` (amd64) — build, test, smoke all passed
- Live Docker execution on `debian:bookworm-slim` (`linux/arm64` via QEMU) — build, test, smoke all passed; `file` verified ARM aarch64 ELF
- `apt-cache search` inside `debian:bookworm-slim` — verified exact package names: `libftdi1-dev`, `libconfuse-dev`, `libcppunit-dev`, `libusb-1.0-0-dev`, `pkg-config`, `build-essential`
- `CMakePresets.json` (repo root) — verified `headless` preset is architecture-agnostic
- `telldus-core/service/CMakeLists.txt` — verified `FIND_LIBRARY(FTDI_LIBRARY ftdi1)` is the search name
- `grep` audit of `telldus-core/` for `__arm__`, `__aarch64__`, `endian`, `BYTE_ORDER` — found only one hit in `3rdparty/openbsd-getopt/sys/types.h`, which is Windows-only code

### Secondary (MEDIUM confidence)
- `docker buildx inspect default` — shows `linux/arm64` platform is supported
- `multiarch/qemu-user-static --reset -p yes` — confirms QEMU binfmt is available and configured for aarch64
- Phase 2 SUMMARY (02-01-SUMMARY.md) — describes repo-root symlink pattern and CMake preset usage constraints

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all package names verified live in target container
- Architecture: HIGH — live aarch64 build succeeded with zero source changes
- Pitfalls: HIGH — all four pitfalls were encountered and resolved during live testing

**Research date:** 2026-05-14
**Valid until:** 30 days (Debian Bookworm is stable; package names unlikely to change)
