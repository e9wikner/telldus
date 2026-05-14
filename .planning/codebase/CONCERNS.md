---
last_mapped: 2026-05-14
last_mapped_commit: b0bc2ed99b5c6ddce804fb76a1d0d8dc5cf3cfe0
focus: concerns
---

# Concerns

## Summary

The codebase is functional but legacy: it uses older build tooling, Qt 4, raw pointer ownership, manual IPC dispatch, platform-specific code, C string buffers, and disabled-by-default tests. Any modernization or feature work should keep blast radius small and verify the affected platform paths explicitly.

## Build and Dependency Age

- Qt 4 is required by `telldus-gui/`, which is obsolete on many modern distributions.
- CMake files target CMake 2.x compatibility and use older macros/policies.
- `telldus-core/CMakeLists.txt` requires `FORCE_COMPILE_FROM_TRUNK=TRUE` to build from the current tree.
- Custom find modules like `FindSignTool.cmake`, `FindTelldusCore.cmake`, and legacy package assumptions may fail on modern systems.
- Dependencies such as libconfuse, libftdi1/ftd2xx, CppUnit, and Qt 4 need explicit environment setup.

## Test Coverage Gaps

- Tests are disabled by default through `ENABLE_TESTING FALSE`.
- Automated tests are concentrated in `telldus-core/tests/`; GUI, scheduler, bindings, examples, xPL, and rfcmd appear untested.
- Hardware behavior is not obviously covered by automated tests.
- No CI configuration was found, so regression confidence depends on local setup.

## Manual Memory and Lifetime

- Many classes allocate raw `PrivateData` pointers and manually delete them.
- Service and client threading code mixes manual stop/wait/cleanup behavior with socket reads and custom events.
- `ClientCommunicationHandler` owns and deletes socket pointers passed from connection listener events.
- Changes to event/thread shutdown paths need careful lifetime review.

## IPC Dispatch Fragility

- `telldus-core/service/ClientCommunicationHandler.cpp` contains a long manual string-dispatch chain matching serialized function names.
- Adding or changing public API calls requires synchronized changes in public headers, client calls, message serialization, service dispatch, and bindings.
- Protocol mismatch can surface as generic communication or unknown response errors.

## C String and Buffer Risks

- `telldus-core/tdtool/main.cpp` builds sensor output with fixed-size buffers and repeated `strcat`.
- `xpl/telldus-core-xpl/xPL_TelldusCore.c` uses `sprintf`, `strcpy`, and `strcat`.
- The vendored cpplint flags these functions generally, but the repository contains existing uses outside test/lint code.
- Any code handling external/hardware data should prefer bounded string operations when touched.

## Security and Secrets

- `scheduler/DeviceScheduler/frmSchedule.cs` decrypts scheduler job passwords with the hard-coded phrase `ThisIsNotParadise`.
- `telldus-gui/Plugins/Live/CMakeLists.txt` defines build-time public/private key cache variables; ensure private values never land in source, generated docs, or committed cache files.
- Example Telldus Live clients use token/request-token/session naming and some HTTP URLs; treat them as sample code, not hardened production code.

## Platform-Specific Risk

- Core behavior differs across Linux, Windows, macOS, and FreeBSD for settings, sockets, service entry points, USB backends, and install paths.
- A change that compiles on Linux may still break Windows service resources, macOS bundle integration, or FreeBSD iconv/device setup.
- The service target name differs by platform (`telldusd` vs `TelldusService`).

## GUI and Plugin Risk

- TelldusCenter uses Qt 4 plugin/script patterns and bundled QtSingleApplication code.
- Plugin build options are split between default `BUILD_PLUGIN_*` and required `REQUIRE_PLUGIN_*` switches.
- QML/script plugins contain many TODO comments, especially in scheduler UI code under `telldus-gui/Plugins/SchedulerGUISimple/`.

## Documentation Drift

- The codebase contains historical bindings, examples, third-party scripts, and platform artifacts that may not match current supported usage.
- Version values are embedded in multiple projects (`telldus-core/` and `telldus-gui/`) and should be kept synchronized.
- Generated and packaged artifacts are interleaved with source resources, increasing the chance of stale assumptions.

## Recommended Guardrails

- Start changes in the smallest relevant module; avoid cross-platform refactors unless the goal is explicitly modernization.
- For C API work, map every caller and binding before changing signatures or behavior.
- For protocol work, add focused protocol tests first or alongside implementation.
- For build modernization, preserve current platform behavior in small steps and document dependency changes.
- For secrets/auth work, avoid writing credentials into CMake cache, examples, docs, or generated mapping files.
