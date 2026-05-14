# Phase 1: Headless Build Boundary - Patterns

## Purpose

Map Phase 1 planned files to existing codebase patterns so execution stays local and conservative.

## Files and Closest Analogs

| Planned File | Role | Closest Existing Analog | Pattern to Preserve |
|--------------|------|-------------------------|---------------------|
| `telldus-core/CMakeLists.txt` | Core project entry point | same file | CMake cache options, `ADD_SUBDIRECTORY`, platform guards |
| `telldus-core/service/CMakeLists.txt` | Linux daemon target and dependencies | same file | target-specific source lists, Linux branch defaults, `FTDI_ENGINE` selection |
| `telldus-core/client/CMakeLists.txt` | Shared C API library target | same file | platform target naming, public header install, `TelldusCommon` dependency |
| `telldus-core/tdtool/CMakeLists.txt` | CLI target | same file | target depends on client library, Unix install/manpage condition |
| `telldus-core/tests/CMakeLists.txt` | Optional test boundary | same file plus `tests/service/CMakeLists.txt` | `ENABLE_TESTING` gate, CppUnit/cpplint/cppcheck registration |
| Project docs, likely `telldus-core/README` or a new focused doc | Build instructions | `telldus-core/README`, `telldus-core/INSTALL` | plain text/Markdown-ish operational instructions |

## Key Existing Patterns

- `telldus-core/` is already independent from `telldus-gui/`; use that as the headless build root.
- Linux daemon target name is `telldusd`; Linux shared library target name is `telldus-core`; CLI target name is `tdtool`.
- Platform support is expressed through `IF(APPLE)`, `ELSEIF(WIN32)`, `ELSE()` branches rather than separate build files.
- Linux default FTDI backend is already `libftdi`; preserve this as v1 default.
- Test build boundary is opt-in through `ENABLE_TESTING`, but may expose static service target and dependency issues.
- Signing is conceptually Windows-only: `FindSignTool.cmake` returns immediately on non-Windows inside `SIGN()`.

## Risks to Plan Around

- `BUILD_LIBTELLDUS-CORE` is declared but the current top-level file still unconditionally adds `client`.
- `FIND_PACKAGE(SignTool REQUIRED)` is called in service/client despite signing being a non-Windows no-op.
- `tdtool` links to `${CMAKE_BINARY_DIR}/client/libtelldus-core.so` on Unix instead of the target variable, which may make target graph proof fragile.
- Local environment currently has `gcc`, `g++`, and `pkg-config`, but not `cmake`.
