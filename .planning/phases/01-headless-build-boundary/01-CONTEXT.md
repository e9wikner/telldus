# Phase 1: Headless Build Boundary - Context

**Gathered:** 2026-05-14T17:44:43+02:00
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1 defines and proves the Linux-only, GUI-free Telldus Core build boundary. It should establish how to configure/build the headless components from `telldus-core/`, identify the minimal allowed dependencies, exclude accidental TelldusCenter/Qt coupling, and produce a dry build proof before Phase 2 begins the broader Arch build/fix loop.

This phase does not implement Docker runtime, Raspberry Pi portability, configuration compatibility validation, hardware behavior, MQTT, or Home Assistant integration. Those are later phases.

</domain>

<decisions>
## Implementation Decisions

### Build Entry Point
- **D-01:** Keep `telldus-core/` as the build root for Phase 1. Do not add a repo-root build entry point in this phase.
- **D-02:** The Phase 1 boundary includes `telldusd`, `libtelldus-core`, `tdtool`, and the test build boundary. Actual test execution and fixes primarily belong to Phase 2.
- **D-03:** Inspect existing CMake options first. Add an explicit CMake option/profile only if the existing build interface is too unclear to make the headless boundary repeatable.

### Dependency Boundary
- **D-04:** The headless target should use minimal required dependencies only: CMake, C/C++ toolchain, pthreads, libconfuse, libftdi/libusb stack, and test tools only when tests are enabled.
- **D-05:** Prefer libftdi for Linux v1. Keep ftd2xx only if it costs almost nothing and does not complicate modern Linux builds.
- **D-06:** If Qt or TelldusCenter leaks into the `telldus-core` headless build, remove that accidental coupling in Phase 1.

### Legacy Platform Handling
- **D-07:** Use guards for Windows/macOS/FreeBSD paths if they interfere with modern Linux cleanup. Do not modernize or delete non-Linux logic in Phase 1.
- **D-08:** Prefer the least invasive CMake fix that unblocks modern Linux. Avoid broad global CMake baseline changes unless they are necessary to define the Linux headless boundary.
- **D-09:** Ignore bindings and examples in Phase 1. The phase is scoped to core service/client/tdtool/test boundary, not binding/example compatibility.

### Success Proof
- **D-10:** Phase 1 is not complete with documentation alone. It should produce a dry build proof: configure plus at least enough target graph/build start to prove dependency and target selection.
- **D-11:** Use local Arch Linux first for the proof. Add a generic Linux container proof only if straightforward.
- **D-12:** If the build cannot configure without deeper modernization, fix only blockers directly tied to defining the headless boundary.
- **D-13:** Produce committed docs/build instructions with exact headless configure/build commands so Phase 2 can reproduce the boundary without guessing.

### the agent's Discretion
- The agent may decide whether an explicit CMake option/profile is needed after inspecting the existing `telldus-core/` CMake structure.
- The agent may keep ftd2xx support if it is effectively free, but should not let it complicate Linux v1.
- The agent may choose the least invasive modern Linux CMake unblock when old platform compatibility is the source of friction.
- The agent may decide whether a generic Linux container proof is cheap enough to include in Phase 1.
- The agent may fix only build blockers that are directly tied to proving the headless boundary.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Scope
- `.planning/PROJECT.md` — Defines Linux-only headless modernization, Docker/native goals, and out-of-scope items.
- `.planning/REQUIREMENTS.md` — Defines v1 requirements and maps Phase 1 to `NBLD-01`.
- `.planning/ROADMAP.md` — Defines Phase 1 goal, success criteria, and plan outline.
- `.planning/STATE.md` — Current project position and deferred items.

### Codebase Map
- `.planning/codebase/STACK.md` — Current build systems, dependencies, and component boundaries.
- `.planning/codebase/ARCHITECTURE.md` — Service/client/headless architecture and extension surfaces.
- `.planning/codebase/INTEGRATIONS.md` — Hardware, IPC, C API, bindings, and platform integration boundaries.
- `.planning/codebase/CONCERNS.md` — Known build age, dependency, platform, and test risks.
- `.planning/codebase/TESTING.md` — Existing CppUnit/cpplint/cppcheck test boundary.

### Source Entry Points
- `telldus-core/CMakeLists.txt` — Current core project root and build options.
- `telldus-core/service/CMakeLists.txt` — Daemon target and Linux service dependencies.
- `telldus-core/client/CMakeLists.txt` — Shared C API library target.
- `telldus-core/tdtool/CMakeLists.txt` — CLI target.
- `telldus-core/tests/CMakeLists.txt` — Optional test boundary.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `telldus-core/CMakeLists.txt`: Existing core build root; should remain the Phase 1 entry point.
- `telldus-core/service/CMakeLists.txt`: Builds `telldusd` on Linux and contains libconfuse/libftdi/ftd2xx selection.
- `telldus-core/client/CMakeLists.txt`: Builds `libtelldus-core` / `TelldusCore`.
- `telldus-core/tdtool/CMakeLists.txt`: Builds `tdtool`, the verification CLI retained for v1.
- `telldus-core/tests/CMakeLists.txt`: Defines optional CppUnit, cpplint, and cppcheck test setup behind `ENABLE_TESTING`.

### Established Patterns
- The repo already separates core and GUI into separate CMake projects: `telldus-core/` and `telldus-gui/`.
- Linux headless components live under `telldus-core/`; TelldusCenter/Qt GUI dependencies live under `telldus-gui/`.
- Platform-specific behavior is handled with CMake and preprocessor branches rather than separate source trees.
- Tests are opt-in and currently tied to `ENABLE_TESTING`.

### Integration Points
- Phase 1 should adjust only the build surface around `telldus-core/`, especially `telldus-core/CMakeLists.txt` and subdirectory CMake files.
- Any documentation produced should point Phase 2 at exact commands for configuring and dry-building the headless boundary.

</code_context>

<specifics>
## Specific Ideas

- The user explicitly wants native and Docker support eventually, but Phase 1 should stay on the headless build boundary.
- The user wants no TelldusCenter GUI work and no Qt dependency in the headless path.
- Phase 1 should use this Arch Linux machine first for proof. A generic Linux container proof is optional if straightforward.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1-Headless Build Boundary*
*Context gathered: 2026-05-14T17:44:43+02:00*
