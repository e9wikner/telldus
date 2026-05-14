---
last_mapped: 2026-05-14
last_mapped_commit: b0bc2ed99b5c6ddce804fb76a1d0d8dc5cf3cfe0
focus: quality
---

# Testing

## Summary

Automated test support exists primarily for `telldus-core`, focused on common utilities and radio protocol behavior. Tests are disabled by default and must be enabled through the CMake cache option `ENABLE_TESTING`.

## Test Frameworks

- CppUnit is used for core unit tests when `ENABLE_TESTING` is enabled.
- `telldus-core/tests/cppunit.cpp` is the test runner.
- `telldus-core/tests/CMakeLists.txt` locates `CPPUNIT` and builds `TestRunner`.
- `cppcheck` is registered as a CTest test on Unix when tests are enabled.
- `cpplint.py` is vendored in `telldus-core/tests/cpplint.py` and registered against core targets.

## Test Layout

- `telldus-core/tests/common/`: Utility tests such as `StringsTest.cpp`.
- `telldus-core/tests/service/`: Protocol tests including `ProtocolNexaTest.cpp`, `ProtocolOregonTest.cpp`, `ProtocolX10Test.cpp`, `ProtocolSartanoTest.cpp`, and others.
- `telldus-core/tests/service/CMakeLists.txt` builds `TelldusServiceTests` from `*Test.cpp`.
- `telldus-core/tests/common/CMakeLists.txt` builds `TelldusCommonTests`.

## Running Tests

Likely flow from a separate build directory:

```bash
cmake -DFORCE_COMPILE_FROM_TRUNK=TRUE -DENABLE_TESTING=TRUE ../telldus-core
cmake --build .
ctest
```

The exact command may need additional system dependencies, including CppUnit, libconfuse, libftdi/ftd2xx, CMake find modules, and platform-specific build tools.

## Style Checks

- cpplint filters in `telldus-core/tests/CMakeLists.txt` explicitly prefer tab indentation.
- Disabled cpplint checks include several whitespace checks, line length, labels, and RTTI.
- The filter comments explain that dynamic_cast is intentionally used for event payloads.
- `cppcheck --quiet --error-exitcode=2 ${CMAKE_SOURCE_DIR}` is available through CTest on Unix.

## Coverage and Gaps

- Core protocol tests exist for several protocol encoders/decoders.
- Common string utility tests exist.
- No automated GUI tests were found for `telldus-gui/`.
- No automated tests were found for `scheduler/`, `bindings/`, `examples/`, `xpl/`, or `rfcmd/`.
- No CI configuration was found in the scanned repository files.

## Test Risk Areas

- Service code is event-driven and hardware-dependent; many paths likely require integration or hardware-in-the-loop testing.
- Client-service IPC dispatch in `ClientCommunicationHandler::parseMessage()` has many manual branches and should be regression-tested when API behavior changes.
- Platform-specific code paths require separate validation on Linux, Windows, macOS, and FreeBSD when touched.
- GUI plugin behavior depends on Qt 4 plugin/script loading and is not covered by automated tests in this repo.

## Recommended Test Strategy

- For protocol changes, add or update focused tests in `telldus-core/tests/service/`.
- For common utility changes, add or update tests in `telldus-core/tests/common/`.
- For C API changes, add service dispatch tests where possible and manually verify through `tdtool`.
- For hardware I/O changes, create a narrow manual verification checklist for TellStick, TellStick Duo, and TellStick Net behavior.
- For GUI/plugin changes, at minimum smoke test TelldusCenter startup, plugin loading, device listing, and command execution.

## Known Build/Test Friction

- `telldus-core/CMakeLists.txt` blocks trunk builds unless `FORCE_COMPILE_FROM_TRUNK` is set.
- Tests are opt-in with `ENABLE_TESTING=TRUE`, so default builds do not validate behavior.
- The build expects legacy dependencies and Qt 4-era tooling that may not exist on modern systems by default.
