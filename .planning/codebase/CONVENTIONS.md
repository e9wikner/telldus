---
last_mapped: 2026-05-14
last_mapped_commit: b0bc2ed99b5c6ddce804fb76a1d0d8dc5cf3cfe0
focus: quality
---

# Conventions

## Summary

The codebase follows older Telldus C/C++ conventions: tab indentation, PIMPL-style private data classes, explicit platform branches, manual memory management, and custom event/thread abstractions. Qt code follows Qt 4 idioms, while C# scheduler code follows older WinForms/.NET project conventions.

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
