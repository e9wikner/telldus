# Phase 3: Raspberry Pi Portability - Context

**Gathered:** 2026-05-14T21:30:00+02:00
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 proves the same headless Telldus Core build path (`telldusd`, `libtelldus-core`, `tdtool`, CppUnit tests) works on Raspberry Pi OS/Debian `aarch64`. It creates a reproducible Debian build environment, maps Debian dependencies, verifies the build compiles and tests pass on the target architecture, and documents any portability issues found.

This phase does not implement Docker runtime (Phase 5), configuration compatibility validation (Phase 4), hardware behavior tests (Phase 7), or create native Raspberry Pi OS deployment packages. Those are later phases.

</domain>

<decisions>
## Implementation Decisions

### Build Verification Method
- **D-03-01:** Use Docker multi-arch build (`docker buildx --platform linux/arm64`) for aarch64 verification. This is reproducible, requires no real Pi, and sets up Phase 5 infrastructure early.
- **D-03-02:** Base image is `debian:bookworm-slim` — matches Raspberry Pi OS (based on Bookworm) and is minimal.
- **D-03-03:** The container build must compile, run CppUnit tests (`ctest -R cppunit`), and perform a `tdtool --help` smoke test. Full verification, not just compilation.

### Debian Dependency Mapping
- **D-03-04:** Create `scripts/install-debian-deps.sh` mirroring the Arch script pattern. Use `apt-get install` with explicit package list.
- **D-03-05:** Include all dependencies in the script: `cmake`, `build-essential`, `libftdi1-dev`, `libconfuse-dev`, `libusb-1.0-0-dev`, `pkg-config`, `libcppunit-dev`.

### CMake Preset Strategy
- **D-03-06:** Reuse the existing `headless` preset from Phase 2. It is architecture-agnostic (cache variables like `FTDI_ENGINE=libftdi` work on any Linux).
- **D-03-07:** Do not create a Debian-specific or aarch64-specific preset unless the build surfaces a real need for architecture-specific cache variables.

### Architecture-Specific Code Audit
- **D-03-08:** Rely on build-and-observe only. The Docker multi-arch build + test suite will surface any real portability issues. No proactive deep static analysis unless the build fails.
- **D-03-09:** If the build fails on aarch64, fix the specific issue. Do not preemptively refactor for hypothetical portability problems.

### the agent's Discretion
- The agent may adjust the Debian package list if `apt-get` reports different package names on bookworm-slim.
- The agent may add Docker build arguments or environment variables if needed for the multi-arch build.
- The agent may document any architecture-specific issues found during the build without fixing them if they belong to a later phase (e.g., USB behavior differences).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Scope
- `.planning/PROJECT.md` — Defines Linux-only headless modernization, Docker/native goals, and out-of-scope items
- `.planning/REQUIREMENTS.md` — Defines v1 requirements and maps Phase 3 to NBLD-03
- `.planning/ROADMAP.md` — Defines Phase 3 goal, success criteria, and plan outline
- `.planning/STATE.md` — Current project position and deferred items

### Phase 1 & 2 Context
- `.planning/phases/01-headless-build-boundary/01-CONTEXT.md` — Prior phase decisions on build boundary
- `.planning/phases/02-arch-native-build/02-CONTEXT.md` — Arch build decisions, CMake presets, test strategy
- `.planning/phases/02-arch-native-build/02-01-SUMMARY.md` — CMake preset and dependency script outcomes
- `.planning/phases/02-arch-native-build/02-02-SUMMARY.md` — Compiler warning fixes and clean build
- `.planning/phases/02-arch-native-build/02-03-SUMMARY.md` — Test enablement and test split documentation

### Codebase Map
- `.planning/codebase/STACK.md` — Current build systems, dependencies, and component boundaries
- `.planning/codebase/ARCHITECTURE.md` — Service/client/headless architecture
- `.planning/codebase/CONCERNS.md` — Known build age, dependency, platform, and test risks

### Source Entry Points
- `telldus-core/CMakeLists.txt` — Core project root and build options
- `telldus-core/service/CMakeLists.txt` — Daemon target and Linux service dependencies
- `telldus-core/client/CMakeLists.txt` — Shared C API library target
- `telldus-core/tests/CMakeLists.txt` — Optional test boundary
- `CMakePresets.json` — Headless preset (architecture-agnostic)
- `scripts/install-arch-deps.sh` — Arch dependency installer (pattern to mirror)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CMakePresets.json`: Existing `headless` preset with `FTDI_ENGINE=libftdi`, `ENABLE_TESTING=TRUE`. Should work unchanged on Debian.
- `scripts/install-arch-deps.sh`: Pattern for dependency installation script — mirror for Debian.
- `build/headless/`: Existing build directory and CMake cache from Phase 2. Can be used as reference for expected artifacts.
- `docs/testing-split.md`: Documents which tests are hardware-independent (all current CppUnit tests).

### Established Patterns
- CMake presets control build configuration in a version-controlled, reproducible way.
- Dependency installation scripts are standalone executables in `scripts/`.
- The build produces three headless targets: `telldusd`, `libtelldus-core.so`, `tdtool`.
- Tests are verified via `ctest -R cppunit` and direct `./build/headless/tests/TestRunner`.

### Integration Points
- The Debian dependency script should integrate with Phase 8 documentation (native build instructions for Raspberry Pi OS/Debian).
- The Docker multi-arch build sets up infrastructure reusable in Phase 5 (Docker runtime).
- The `headless` preset should be validated on Debian without modification.

</code_context>

<specifics>
## Specific Ideas

- Docker multi-arch build requires `docker buildx` with QEMU user-mode emulation (`linux/arm64` platform).
- Debian package names: `libftdi1-dev`, `libconfuse-dev`, `libusb-1.0-0-dev`, `libcppunit-dev` (may need adjustment for bookworm-slim).
- The build should be proven in a container first; native Raspberry Pi build verification is a bonus if hardware is available.
- If the Docker build succeeds, it demonstrates that the code is portable; any remaining issues would likely be runtime/hardware-specific (Phase 7).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 3-Raspberry Pi Portability*
*Context gathered: 2026-05-14T21:30:00+02:00*
