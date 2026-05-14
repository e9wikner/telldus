---
last_mapped: 2026-05-14
last_mapped_commit: b0bc2ed99b5c6ddce804fb76a1d0d8dc5cf3cfe0
focus: arch
---

# Structure

## Top-Level Layout

- `telldus-core/`: Core service, public C API library, CLI tools, admin tools, common support library, tests, and documentation/build files.
- `telldus-gui/`: Qt 4 desktop GUI library, TelldusCenter application, plugins, GUI resources, translations, and CMake modules.
- `bindings/`: Language bindings for .NET, Java, PHP, Python, SWIG, and Visual Basic.
- `examples/`: Example clients in C, C++, .NET, Java, PHP, and Python.
- `scheduler/`: C# Windows scheduler applications and handler/agent projects.
- `xpl/`: xPL implementations and bridges in C, Qt/C++, Python, and PHP.
- `rfcmd/`: Standalone C RF command tooling.
- `3rdparty/`: Bundled legacy scripts and wrappers, including tellstickd, tellstickcontroller, and tellstick.net.
- `docs/`: Doxygen documentation pages for Telldus Core and TellStick protocols.

## Telldus Core

- `telldus-core/CMakeLists.txt`: Project-level build options, version, subdirectories, tests, and optional docs.
- `telldus-core/common/`: Cross-platform utility types: `Event`, `EventHandler`, `Message`, `Mutex`, `Socket`, `Strings`, and `Thread`.
- `telldus-core/client/`: Shared library and exported C API; key files include `telldus-core.h`, `telldus-core.cpp`, `Client.cpp`, and callback dispatchers.
- `telldus-core/service/`: Daemon/service implementation, protocols, hardware I/O, settings, logging, managers, and platform main files.
- `telldus-core/tdtool/`: CLI client that calls the C API.
- `telldus-core/tdadmin/`: Platform administration helpers such as udev rules.
- `telldus-core/tests/`: CppUnit tests and cpplint integration.
- `telldus-core/cmake/`: Custom CMake find modules.

## Telldus GUI

- `telldus-gui/CMakeLists.txt`: GUI project entry point.
- `telldus-gui/TelldusGui/`: Shared widget/model library for devices, device settings, methods, vendor/device metadata, icons, resources, and translations.
- `telldus-gui/TelldusCenter/`: Main desktop app, application class, main window, plugin tree, script environment, configuration dialog, desktop metadata, and platform bundle files.
- `telldus-gui/Plugins/`: Script/plugin modules for devices, controllers, sensors, systray, TelldusCore, Live, scheduler UI, settings, QML, touch interface, and form loading.
- `telldus-gui/3rdparty/`: Bundled QtSingleApplication and Qt component CMake helpers.
- `telldus-gui/cmake/`: Find modules for TelldusCore, QCA, and SignTool.

## Naming Conventions

- C++ headers and sources are generally paired as `.h`/`.cpp`.
- Protocol classes use `Protocol{Name}.h` and `Protocol{Name}.cpp`.
- Platform-specific implementations use suffixes such as `_win`, `_unix`, `_mac`, `WinRegistry`, `CoreFoundationPreferences`, `Confuse`, `libftdi`, and `ftd2xx`.
- Qt plugin directories are named by feature (`Sensors`, `Controllers`, `Live`, `TelldusCore`) and commonly include `CMakeLists.txt`, plugin source files, scripts, resources, and translations.
- Examples are grouped first by language and then by feature area.

## Entry Points

- Core service: `telldus-core/service/main_unix.cpp`, `main_win.cpp`, and `main_mac.cpp`.
- Service orchestrator: `telldus-core/service/TelldusMain.cpp`.
- Public API: `telldus-core/client/telldus-core.h` and `telldus-core/client/telldus-core.cpp`.
- CLI: `telldus-core/tdtool/main.cpp`.
- GUI app: `telldus-gui/TelldusCenter/main.cpp`.
- Scheduler apps: `scheduler/DeviceScheduler/Program.cs` and `scheduler/DeviceSchedulerAgent/Program.cs`.

## Test Locations

- `telldus-core/tests/common/`: Common library tests.
- `telldus-core/tests/service/`: Protocol/service tests such as `ProtocolNexaTest.cpp`, `ProtocolOregonTest.cpp`, and `ProtocolX10Test.cpp`.
- `telldus-core/tests/cppunit.cpp`: Test runner.
- No comparable automated test tree was found for GUI, scheduler, bindings, or xPL components.

## Generated/Resource Assets

- Qt resources: `.qrc` files in GUI and plugins.
- Translations: `.ts` files such as `TelldusGui_sv.ts` and `TelldusCenter_sv.ts`.
- Windows resources: `.rc.in`, `.mc`, `.ico`, `.resx`, and designer files.
- macOS resources: `.icns`, `Info.plist.in`, service plist, and bundle fixup scripts.
- Device/vendor metadata: XML files under `telldus-gui/TelldusGui/data/`.

## Directory Ownership Heuristic

- Changes to hardware/protocol behavior usually belong in `telldus-core/service/`.
- Changes to API shape belong in `telldus-core/client/telldus-core.h` and matching client/service dispatch code.
- Changes to user-visible device configuration UI belong in `telldus-gui/TelldusGui/`.
- Changes to desktop shell/plugin loading belong in `telldus-gui/TelldusCenter/` and `telldus-gui/Plugins/`.
- Changes to language-specific integration belong under `bindings/` and should be checked against matching examples.
