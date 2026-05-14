# Phase 2: Arch Native Build - Context

**Gathered:** 2026-05-14T20:08:00+02:00
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 builds and tests the headless Telldus Core components (`telldusd`, `libtelldus-core`, `tdtool`) on the local Arch Linux machine. It captures required Arch packages and build flags, fixes modern compiler and dependency breakages, and runs practical automated tests without requiring TellStick hardware.

This phase does not implement Raspberry Pi portability, Docker runtime, configuration compatibility validation, hardware behavior tests, MQTT, or Home Assistant integration. Those are later phases.

</domain>

<decisions>
## Implementation Decisions

### Build Dependency Management
- **D-02-01:** Create `scripts/install-arch-deps.sh` for automated dependency installation — reduces copy-paste errors, automation-friendly
- **D-02-02:** Official Arch repos only, warn if dependencies missing or require AUR — balanced approach, official packages guaranteed, AUR is user-managed
- **D-02-03:** Use pacman's idempotency — run `pacman -S` commands directly, simpler script, pacman handles already-installed packages gracefully
- **D-02-04:** Make script standalone executable (`./scripts/install-arch-deps.sh`) — most intuitive, standard pattern for installation scripts

### Compiler Modernization Level
- **D-02-05:** Fix errors + critical warnings (deprecated features, security issues) — balanced safety vs effort, improves code quality without over-engineering
- **D-02-06:** Treat as critical: security warnings, deprecation warnings, implicit conversion warnings — comprehensive safety net covering security, future compatibility, and data integrity
- **D-02-07:** Fix difficult warnings even if major refactoring is required — don't leave technical debt, ensure clean build from the start
- **D-02-08:** Add warning flags to `CMakeLists.txt` directly — enforces the standard for all future builds, ensures consistency

### Test Enablement Strategy
- **D-02-09:** Enable all tests and fix everything that fails — comprehensive verification as part of "make it build and test" goal
- **D-02-10:** Enable CppUnit unit tests only (skip cpplint and cppcheck for now) — focus on core functionality verification first
- **D-02-11:** Fix all test failures inline during Phase 2 — part of the "make it build and test" goal, don't defer fixes
- **D-02-12:** Split tests: unit tests without hardware, separate integration tests with hardware — best of both: CI-friendly unit tests and comprehensive hardware validation

### Build Output Location
- **D-02-13:** Use `build/` at repo root with subdirs for different configs — organized structure supporting multiple build configurations
- **D-02-14:** Use CMake presets for standardized build configuration management — modern CMake approach, version-controlled build configurations
- **D-02-15:** Add `build/` to `.gitignore` — standard practice, build artifacts shouldn't be committed

### the agent's Discretion
- The agent may determine which specific packages need to be in `install-arch-deps.sh` based on CMake errors encountered
- The agent may adjust warning flags if certain warnings are excessively noisy or not applicable
- The agent may organize the test split (unit vs integration) based on existing test structure
- The agent may choose CMake preset names and structure based on common conventions

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Scope
- `.planning/PROJECT.md` — Defines Linux-only headless modernization, Docker/native goals, and out-of-scope items
- `.planning/REQUIREMENTS.md` — Defines v1 requirements and maps Phase 2 to NBLD-02, NBLD-04
- `.planning/ROADMAP.md` — Defines Phase 2 goal, success criteria, and plan outline
- `.planning/STATE.md` — Current project position and deferred items

### Phase 1 Context
- `.planning/phases/01-headless-build-boundary/01-CONTEXT.md` — Prior phase decisions on build boundary
- `.planning/phases/01-headless-build-boundary/01-BUILD-BOUNDARY.md` — Headless build boundary documentation

### Codebase Map
- `.planning/codebase/STACK.md` — Current build systems, dependencies, and component boundaries
- `.planning/codebase/ARCHITECTURE.md` — Service/client/headless architecture
- `.planning/codebase/CONCERNS.md` — Known build age, dependency, platform, and test risks
- `.planning/codebase/TESTING.md` — Existing CppUnit/cpplint/cppcheck test boundary

### Source Entry Points
- `telldus-core/CMakeLists.txt` — Core project root and build options
- `telldus-core/service/CMakeLists.txt` — Daemon target and Linux service dependencies
- `telldus-core/client/CMakeLists.txt` — Shared C API library target
- `telldus-core/tdtool/CMakeLists.txt` — CLI target
- `telldus-core/tests/CMakeLists.txt` — Optional test boundary

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `telldus-core/CMakeLists.txt`: Existing core build root with `BUILD_LIBTELLDUS-CORE`, `BUILD_TDTOOL`, `BUILD_TDADMIN`, `ENABLE_TESTING` options
- `telldus-core/service/CMakeLists.txt`: Builds `telldusd` on Linux with libconfuse/libftdi dependencies
- `telldus-core/tests/CMakeLists.txt`: CppUnit test framework setup behind `ENABLE_TESTING`
- Phase 1 proof commands in `telldus-core/README`: Starting point for Arch build verification

### Established Patterns
- CMake options control component inclusion rather than separate build systems
- Platform-specific code uses preprocessor branches (`#ifdef _LINUX`)
- Tests are opt-in via `ENABLE_TESTING` cache variable
- Service depends on `TelldusCommon` static library

### Integration Points
- Dependency installation script should integrate with existing documentation in `telldus-core/README`
- Compiler warning flags should be added to `telldus-core/CMakeLists.txt` for global effect
- CMake presets should reference the existing configure commands from Phase 1
- Test fixes should maintain compatibility with existing test infrastructure

</code_context>

<specifics>
## Specific Ideas

- CMake is now installed on the system (was missing during Phase 1)
- Arch Linux packages to consider: cmake, gcc, libftdi, libconfuse, libusb, pkg-config, cppunit (for tests)
- The user wants a clean build with all warnings fixed, not just suppressed
- Test split should allow Phase 7 (hardware verification) to run integration tests with actual TellStick

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 2-Arch Native Build*
*Context gathered: 2026-05-14T20:08:00+02:00*
