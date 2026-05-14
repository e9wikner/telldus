---
last_mapped: 2026-05-14
last_mapped_commit: b0bc2ed99b5c6ddce804fb76a1d0d8dc5cf3cfe0
focus: arch
---

# Architecture

## Summary

The core architecture is a local service plus client library. Applications call the exported Telldus Core C API, the client library serializes API calls to a local daemon/service, and the service coordinates configured devices, controllers, protocols, sensors, and event callbacks.

## Main Layers

- Public API layer: `telldus-core/client/telldus-core.h` exports `td*` C functions and constants for client applications.
- Client IPC layer: `telldus-core/client/Client.cpp`, `CallbackDispatcher.cpp`, and `CallbackMainDispatcher.cpp` manage service calls and callback delivery.
- Common support layer: `telldus-core/common/` contains sockets, messages, events, threading, mutexes, and string conversion helpers shared by client and service.
- Service orchestration layer: `telldus-core/service/TelldusMain.cpp` wires listeners, managers, timers, events, and the main service loop.
- Domain manager layer: `DeviceManager`, `ControllerManager`, `EventUpdateManager`, `Settings`, and `Log` hold service behavior.
- Hardware/protocol layer: `TellStick_*`, `Controller`, `ControllerMessage`, `Protocol*`, and `Sensor` implement controller I/O and radio protocol encode/decode.

## Core Data Flow

1. A caller initializes through `tdInit()` and invokes API functions from `telldus-core/client/telldus-core.h`.
2. `telldus-core/client/telldus-core.cpp` delegates to the singleton `TelldusCore::Client`.
3. `Client::sendToService()` serializes a `TelldusCore::Message` and connects to the `TelldusClient` local endpoint.
4. `telldus-core/service/ConnectionListener_*` accepts the connection in the service.
5. `ClientCommunicationHandler::parseMessage()` maps request names to manager operations.
6. `DeviceManager` resolves devices/protocols and chooses a controller through `ControllerManager`.
7. `TellStick_*` sends data to hardware and reads controller events.
8. Events are published through `EventUpdateManager` and read by clients on `TelldusEvents`.

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
