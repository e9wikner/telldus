<!-- GSD:project-start source:PROJECT.md -->
## Project

**Telldus Core Modern Linux Support**

This project modernizes the existing Telldus Core codebase so it can compile and run headlessly on current Linux systems, especially Arch Linux for local development and Raspberry Pi OS/Debian on `aarch64` for Home Assistant-adjacent deployment. The first goal is to restore reliable TellStick Duo operation without requiring TelldusCenter, Qt GUI components, device re-pairing, or replacement of an existing `/etc/tellstick.conf`.

Docker is part of the target workflow: a provided TellStick configuration file should be bind-mounted into a container as `/etc/tellstick.conf`, the daemon should run there, and the setup should behave like the same device connected to the Raspberry Pi. Native Linux support remains equally important so Telldus Core can run directly on Arch Linux or Raspberry Pi OS when desired.

**Core Value:** Existing 433 MHz devices controlled by a TellStick Duo must keep working on modern Linux, using the existing configuration file, without re-learning or re-pairing devices.

### Constraints

- **Scope**: Linux-only v1 — avoids spending effort on Windows/macOS/FreeBSD code paths that are not needed now.
- **UI**: No TelldusCenter/Qt GUI work — avoids Qt 4 dependency and keeps the deliverable headless.
- **Hardware**: TellStick Duo must be testable — compile-only success is not enough for v1.
- **Configuration**: Existing `/etc/tellstick.conf` compatibility is mandatory — users should not need to re-learn devices around the house.
- **Runtime**: Docker and native Linux both matter — Docker should support bind-mounted config and USB device passthrough; native should work directly on Arch and Raspberry Pi OS/Debian.
- **Verification**: `tdtool` remains part of v1 — it is the existing control surface for proving runtime behavior before MQTT exists.
- **Future Integration**: MQTT/Home Assistant is deferred — design choices should not block it, but v1 should not depend on it.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Summary
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Summary
## C++ Style
- Indentation uses tabs; `telldus-core/tests/CMakeLists.txt` configures cpplint to prefer tab indentation and disables whitespace checks that conflict with this style.
- Header guards use uppercase path-style names, for example `TELLDUS_CORE_SERVICE_PROTOCOL_H_`.
- Copyright headers appear on core source files and reference the distribution COPYING file.
- Many classes use nested `PrivateData` PIMPL storage with raw pointers, for example `Client::PrivateData`, `TelldusMain::PrivateData`, and `ControllerManager::PrivateData`.
- Constructors allocate `d = new PrivateData`; destructors manually stop threads, close handles, and `delete d`.
## API and Naming
- Public C API functions are prefixed with `td`, such as `tdInit`, `tdTurnOn`, and `tdSensorValue`.
- Public constants use `TELLSTICK_*`.
- Service/client message names match public function names as wide strings, for example `L"tdTurnOn"` in `ClientCommunicationHandler::parseMessage()`.
- Protocol class names are concrete and vendor/model oriented, such as `ProtocolNexa`, `ProtocolOregon`, and `ProtocolEverflourish`.
## Error Handling
- Core public API returns integer status codes defined in `telldus-core/client/telldus-core.h`.
- Common errors include `TELLSTICK_ERROR_DEVICE_NOT_FOUND`, `TELLSTICK_ERROR_CONNECTING_SERVICE`, and `TELLSTICK_ERROR_COMMUNICATING_SERVICE`.
- Client-service operations often return either an integer error/status or a serialized string response through `TelldusCore::Message`.
- Qt plugin wrapper methods emit `errorOccurred` after failed core API calls, as seen in `telldus-gui/Plugins/TelldusCore/tellduscoreobject.cpp`.
## Threading and Events
- The project uses custom `TelldusCore::Thread`, `Event`, `EventHandler`, `Mutex`, and `MutexLocker` abstractions from `telldus-core/common/`.
- Service request handling spins `ClientCommunicationHandler` threads per connection.
- Client callbacks are dispatched from a background client event listener thread.
- Hardware access code uses both custom mutexes and native pthread primitives in the libftdi backend.
## String and Encoding Patterns
- Public C API uses `char *`/UTF-8-facing interfaces.
- Internals often use `std::wstring` and conversion helpers from `telldus-core/common/Strings.*`.
- Message serialization/deserialization uses `TelldusCore::Message::takeString`, `takeInt`, and `addArgument`.
- Qt layers convert API strings to `QString::fromUtf8` and release returned strings with `tdReleaseString`.
## Build Conventions
- CMake files use uppercase command style in older modules (`SET`, `IF`, `ADD_SUBDIRECTORY`) with platform-specific branches.
- Build options are cache booleans such as `BUILD_TDTOOL`, `BUILD_TDADMIN`, `BUILD_PLUGIN_SENSORS`, and `ENABLE_TESTING`.
- Targets expose platform-specific names through variables such as `telldus-service_TARGET` and `telldus-core_TARGET`.
- Custom `SIGN(...)` CMake macro/function is expected from `FindSignTool.cmake`.
## Qt Conventions
- Qt 4 macros are used: `QT4_WRAP_CPP`, `QT4_AUTOMOC`, `QT4_ADD_RESOURCES`, and `QT4_ADD_TRANSLATION`.
- Plugin classes implement Qt script/plugin interfaces with `initialize()` and `keys()` methods.
- QML plugins store UI components, scripts, images, and `qmldir` in each plugin directory.
- Translations are Swedish-focused by default through `LANGUAGES sv`.
## C and Legacy Conventions
- C utilities and xPL code use C string buffers and functions such as `sprintf`, `strcpy`, and `strcat`.
- Python examples use Python 2 syntax in several places.
- PHP examples use older OAuth-style helper objects and session storage.
- Visual Basic and old Visual Studio artifacts are retained as binding examples.
## Documentation Conventions
- Doxygen docs live under `docs/` and `telldus-core/Doxyfile.in`.
- Build documentation can be generated through the `GENERATE_DOXYGEN` CMake option.
- Protocol documentation exists as `.dox` files such as `docs/02-tellstick-protocol.dox` and `docs/03-tellstick-net-protocol.dox`.
## Practical Change Guidance
- Preserve tab indentation in existing C/C++ files.
- Keep platform-specific code paths explicit rather than trying to collapse them without cross-platform testing.
- When adding C API functions, update the public header, client serialization, service dispatch, bindings as needed, and examples/tests where relevant.
- When adding a protocol, mirror existing `Protocol{Name}` structure and add targeted protocol tests under `telldus-core/tests/service/`.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Summary
## Main Layers
- Public API layer: `telldus-core/client/telldus-core.h` exports `td*` C functions and constants for client applications.
- Client IPC layer: `telldus-core/client/Client.cpp`, `CallbackDispatcher.cpp`, and `CallbackMainDispatcher.cpp` manage service calls and callback delivery.
- Common support layer: `telldus-core/common/` contains sockets, messages, events, threading, mutexes, and string conversion helpers shared by client and service.
- Service orchestration layer: `telldus-core/service/TelldusMain.cpp` wires listeners, managers, timers, events, and the main service loop.
- Domain manager layer: `DeviceManager`, `ControllerManager`, `EventUpdateManager`, `Settings`, and `Log` hold service behavior.
- Hardware/protocol layer: `TellStick_*`, `Controller`, `ControllerMessage`, `Protocol*`, and `Sensor` implement controller I/O and radio protocol encode/decode.
## Core Data Flow
## Service Event Loop
- `TelldusMain::start()` constructs the service runtime: client listener, data event, execute-action event, controller manager, device manager, and a janitor timer.
- The loop waits on a shared `EventHandler`, then routes signals for new clients, controller changes, controller data, handler cleanup, deferred actions, and periodic controller status checks.
- Client request handling is threaded: each accepted client connection becomes a `ClientCommunicationHandler` thread and is cleaned up through a handler event.
## Protocol Model
- `Protocol` in `telldus-core/service/Protocol.h` is an abstract base class with `methods()` and `getStringForMethod()`.
- Individual protocol implementations live in files such as `ProtocolNexa.cpp`, `ProtocolX10.cpp`, `ProtocolOregon.cpp`, and `ProtocolEverflourish.cpp`.
- `Device` and `DeviceManager` combine settings parameters with protocol instances to produce raw controller command strings.
- Sensor decode paths are in `Protocol::decodeData()` and `DeviceManager::handleSensorMessage()`.
## Configuration and State
- `Settings` abstracts platform-specific storage.
- Linux settings use libconfuse in `telldus-core/service/SettingsConfuse.cpp`.
- Windows settings use registry storage in `SettingsWinRegistry.cpp`.
- macOS settings use CoreFoundation preferences in `SettingsCoreFoundationPreferences.cpp`.
- Stable user/device config is separated from variable state; Linux paths are based on `CONFIG_PATH` and `VAR_CONFIG_PATH`.
## GUI Architecture
- `telldus-gui/TelldusCenter/main.cpp` creates `TelldusCenterApplication`, loads translations, initializes plugins, and shows the main window.
- `telldus-gui/TelldusGui/` provides shared Qt widgets/models for device management.
- TelldusCenter plugins expose script objects and UI modules; `telldus-gui/Plugins/TelldusCore/tellduscoreobject.cpp` bridges Qt scripts to the core C API.
- GUI device metadata and vendor/device resources are stored in `telldus-gui/TelldusGui/data/`.
## CLI and Admin Tools
- `telldus-core/tdtool/main.cpp` is the command-line user interface for listing devices/sensors and sending commands.
- `telldus-core/tdadmin/main.cpp` handles administrative setup and permissions.
- `rfcmd/` is a separate low-level C tool for RF command interaction.
## Extension Surfaces
- The C API is the stable integration surface for bindings and examples.
- The Qt plugin system is the desktop extension surface.
- Protocol subclasses are the core extension point for radio protocol support.
- Language bindings wrap the C API rather than duplicating service logic.
## Architectural Constraints
- The service/client boundary is string-message based and manually dispatched.
- The code uses older C++ patterns: PIMPL classes with raw pointers, manual memory management, custom threading/events, and platform preprocessor branches.
- Build and install logic is deeply platform-specific, so changes to CMake/service behavior must be tested per target platform.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
