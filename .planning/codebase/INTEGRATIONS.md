---
last_mapped: 2026-05-14
last_mapped_commit: b0bc2ed99b5c6ddce804fb76a1d0d8dc5cf3cfe0
focus: tech
---

# Integrations

## Summary

The repository integrates local TellStick hardware, platform service managers, Telldus Live examples/plugins, desktop GUI plugin APIs, xPL home automation messaging, and many language binding surfaces. Most integrations are local process, USB, socket, or desktop plugin integrations rather than hosted web services.

## Hardware

- TellStick USB controllers are represented by `telldus-core/service/TellStick.h` and implemented through `TellStick_libftdi.cpp` or `TellStick_ftd2xx.cpp`.
- `telldus-core/service/ControllerManager.cpp` detects Telldus USB vendor/product IDs `0x1781`, `0x0C30`, and `0x0C31`.
- `telldus-core/service/Controller.cpp` and `ControllerMessage.cpp` model controller messages and publish decoded data to device/sensor handling.
- `telldus-gui/Plugins/Controllers/firmware/` contains firmware hex files for TellStick, TellStick Duo, and TellStick Net.

## Client-Service IPC

- `telldus-core/client/Client.cpp` talks to the service over named socket endpoints `TelldusClient` and `TelldusEvents`.
- `telldus-core/service/ConnectionListener_*` accepts service-side client connections.
- `telldus-core/service/ClientCommunicationHandler.cpp` dispatches request names such as `tdTurnOn`, `tdGetName`, `tdSensor`, and `tdController` to `DeviceManager` and `ControllerManager`.
- `telldus-core/common/Message.*` provides the argument serialization/deserialization layer used by both client and service.

## Public C API

- `telldus-core/client/telldus-core.h` exposes the main integration API for external callers.
- API consumers can initialize/close, enumerate devices, trigger commands, read sensors/controllers, send raw commands, manage device metadata, and register callbacks.
- Callback types include device events, device change events, raw device events, sensor events, and controller events.
- `telldus-core/tdtool/main.cpp` demonstrates use of the C API from a CLI client.

## Language Bindings

- `bindings/swig/tellduscore.i` provides SWIG input for generated bindings.
- `bindings/python/native/telldus.c` and `bindings/python/native/setup.py` provide a Python extension.
- `bindings/php/telldus.c` and `bindings/php/config.m4` provide a PHP extension.
- `bindings/java/tellstick.c`, `bindings/java/tellstick.h`, and `bindings/java/tellstick.java` provide Java/JNI binding pieces.
- `bindings/dotnet/TelldusNETWrapper/` provides a .NET wrapper project.
- `bindings/visual-basic/TellStick.bas` provides a Visual Basic API module.

## Telldus Live

- `telldus-gui/Plugins/Live/` contains a Telldus Live desktop plugin implementation with token/message classes and bundled CA certificates.
- `telldus-gui/Plugins/Live/CMakeLists.txt` defines empty cache strings `TELLDUS_LIVE_PUBLIC_KEY` and `TELLDUS_LIVE_PRIVATE_KEY`.
- `examples/python/live/tdtool/tdtool.py` and `examples/php/live/authentication/` demonstrate OAuth-style Telldus Live API flows against `api.telldus.com`.
- `examples/python/live/server/` contains a Python protocol/server example around live messages and message tokens.

## xPL

- `xpl/qtxpl/` is a Qt xPL implementation.
- `xpl/pyxpl/` and `xpl/phpxpl/` provide Python/PHP xPL helpers.
- `xpl/telldus-core-xpl/xPL_TelldusCore.c` bridges Telldus Core functionality into xPL lighting/device messages.

## Desktop Plugin System

- `telldus-gui/TelldusCenter/tellduscenterplugin.h` defines the TelldusCenter plugin interface.
- `telldus-gui/TelldusCenter/scriptenvironment.cpp` and related classes load and expose script/plugin functionality.
- `telldus-gui/Plugins/TelldusCore/tellduscoreobject.cpp` wraps the C API as a QObject for script/plugin use.
- Plugin directories include `Devices`, `Controllers`, `Sensors`, `Systray`, `Scheduler`, `SunCalculator`, `QML`, `Settings`, `Live`, `FormLoader`, and `TouchInterface`.

## Platform Integration

- Linux device permissions and service/admin support are in `telldus-core/tdadmin/udev.sh`, `05-tellstick.rules`, and service install configs.
- macOS service/app bundle integration uses `telldus-core/service/com.telldus.service.plist`, `telldus-gui/TelldusCenter/Info.plist.in`, and bundle fixup logic.
- Windows service integration uses `telldus-core/service/TelldusWinService_win.*` and `telldus-core/service/Messages.mc`.
- `3rdparty/tellstickd/` and `3rdparty/tellstickcontroller/` contain legacy daemon/controller scripts.

## External Service and Network Touch Points

- Telldus Live examples and plugin code are the main remote API integration points.
- xPL integrations use network-discoverable home automation messaging.
- Core service IPC is local, but it is socket-based and should be treated as an integration boundary.

## Integration Risks

- Some Telldus Live example code uses old Python/PHP idioms and non-HTTPS `http://api.telldus.com` URLs.
- The Live plugin expects public/private keys to be provided at build time; secrets should not be committed into generated build cache or source files.
- Hardware access depends on platform USB libraries and device permission configuration.
