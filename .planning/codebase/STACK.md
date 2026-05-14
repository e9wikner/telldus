---
last_mapped: 2026-05-14
last_mapped_commit: b0bc2ed99b5c6ddce804fb76a1d0d8dc5cf3cfe0
focus: tech
---

# Stack

## Summary

This repository is a legacy Telldus/TellStick codebase centered on C and C++ components, with a Qt 4 desktop GUI, C# scheduler utilities, language bindings, example clients, and xPL integrations. The main build system is CMake, with several older project formats kept for platform-specific or historical consumers.

## Primary Languages

- C++: Core daemon, client library, command-line tools, Qt GUI, Qt plugins, and xPL Qt implementation.
- C: Native bindings and low-level tools, including `rfcmd/` and language extension glue.
- C#: Windows scheduler and .NET wrapper projects under `scheduler/` and `bindings/dotnet/`.
- Python, PHP, Java, Visual Basic: bindings and examples under `bindings/`, `examples/`, and `xpl/`.
- QML and JavaScript: TelldusCenter plugin UI/script pieces under `telldus-gui/Plugins/`.

## Build Systems

- CMake is the main build system for `telldus-core/`, `telldus-gui/`, `rfcmd/`, and `xpl/qtxpl/`.
- qmake project files remain for Qt components, including `telldus-gui/TelldusGui/TelldusGui.pro`, `telldus-gui/TelldusCenter/TelldusCenter.pro`, and `xpl/qtxpl/qtxpl.pro`.
- Visual Studio project files exist for C#/.NET components, such as `scheduler/DeviceScheduler/DeviceScheduler.csproj`, `scheduler/DeviceSchedulerAgent/DeviceSchedulerAgent.csproj`, and `bindings/dotnet/TelldusNETWrapper/TelldusNETWrapper.csproj`.
- Hand-written Makefiles exist for smaller C/xPL components, including `rfcmd/Makefile` and `xpl/telldus-core-xpl/Makefile`.

## Core Runtime Components

- `telldus-core/CMakeLists.txt` defines Telldus Core version `2.1.3_beta1`, builds `common`, `service`, `client`, optional `tdtool`, optional `tdadmin`, and tests.
- `telldus-core/service/CMakeLists.txt` builds the platform service target: `telldusd` on Linux and `TelldusService` on Windows/macOS.
- `telldus-core/client/CMakeLists.txt` builds the shared C API library target: `telldus-core` on Linux and `TelldusCore` on Windows/macOS.
- `telldus-core/common/CMakeLists.txt` builds `TelldusCommon`, a static support library for sockets, threading, events, messages, mutexes, and strings.

## GUI Stack

- `telldus-gui/CMakeLists.txt` builds `TelldusGui` and `TelldusCenter`, controlled by `BUILD_LIBTELLDUS-GUI` and `BUILD_TELLDUS-CENTER`.
- `telldus-gui/TelldusGui/CMakeLists.txt` uses Qt 4, links against Telldus Core, and builds a shared GUI library/framework.
- `telldus-gui/TelldusCenter/CMakeLists.txt` uses Qt 4 modules including QtScript, QtNetwork, and QtUiTools, plus bundled QtSingleApplication support.
- `telldus-gui/Plugins/CMakeLists.txt` builds a plugin set with default-enabled plugins for TelldusCore, Devices, Systray, Controllers, and Sensors.

## Key Dependencies

- Qt 4: GUI library, TelldusCenter application, plugins, translations, resources, scripts, and optional QML/declarative support.
- libftdi1 or ftd2xx: TellStick USB communication backend selected by `FTDI_ENGINE` in `telldus-core/service/CMakeLists.txt`.
- libconfuse: Linux configuration parsing through `telldus-core/service/SettingsConfuse.cpp`.
- pthreads / platform thread libraries: Pulled by CMake `FindThreads` in service/client builds.
- CppUnit: Optional C++ unit test framework when `ENABLE_TESTING` is set.
- Doxygen, xsltproc/docbook stylesheets: Optional documentation/manpage generation.
- SignTool: Custom CMake package required by both core and GUI builds.

## Platform Support

- Linux: Defines `_LINUX`, uses libconfuse, libftdi by default, installs daemon support files and udev/admin assets.
- Windows: Defines `_WINDOWS`/`UNICODE`, builds `TelldusService`, resource files, and DLL exports/imports.
- macOS: Defines `_MACOSX`, uses CoreFoundation/IOKit, bundle frameworks, Info.plist files, and app bundle fixups.
- FreeBSD: Has explicit include/library path handling and device admin config support.

## Configuration Files

- `telldus-core/service/tellstick.conf` and generated install path `/etc/tellstick.conf` define configured devices/controllers.
- `telldus-core/service/telldus-core.conf` stores variable device state through `VAR_CONFIG_PATH`.
- `telldus-core/service/config.h.in` receives CMake install paths and build configuration.
- `telldus-core/tdadmin/05-tellstick.rules` and `telldus-core/tdadmin/freebsd-devd-tellstick.conf` support device permissions.

## Notes

- The root does not have a single top-level `CMakeLists.txt`; `telldus-core/` and `telldus-gui/` are separate CMake projects.
- `telldus-core/CMakeLists.txt` intentionally aborts trunk builds unless `FORCE_COMPILE_FROM_TRUNK` is enabled.
- The project uses older CMake and Qt idioms, including CMake 2.x compatibility, Qt 4 macros, and platform-specific bundle/install rules.
