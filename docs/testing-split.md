# Unit vs Integration Test Split

## Purpose

This document classifies every CppUnit test in the Telldus Core test suite so that:

- **Unit tests** run in CI without any TellStick hardware connected.
- **Integration tests** are reserved for hardware-in-the-loop validation (Phase 7).

All tests listed below are pure logic tests — they exercise encode/decode algorithms and string utilities with no external hardware, socket I/O, or file-system dependencies.

---

## Unit Tests

Unit tests are those that exercise pure logic, encode/decode algorithms, or string utilities with no hardware dependency.

| Test | File | What It Tests | Hardware Required |
|------|------|---------------|-------------------|
| `StringsTest` | `telldus-core/tests/common/StringsTest.cpp` | `TelldusCore::formatf` string formatting with `%u`, `%X`, `%s` | None |
| `ProtocolEverflourishTest` | `telldus-core/tests/service/ProtocolEverflourishTest.cpp` | Everflourish protocol decode — house/unit/method extraction from raw controller message bytes | None |
| `ProtocolHastaTest` | `telldus-core/tests/service/ProtocolHastaTest.cpp` | Hasta protocol decode — version 1 and version 2 self-learning frame parsing (up/down methods) | None |
| `ProtocolNexaTest` | `telldus-core/tests/service/ProtocolNexaTest.cpp` | Nexa/Arctech protocol decode — codeswitch and self-learning house/unit/method extraction | None |
| `ProtocolOregonTest` | `telldus-core/tests/service/ProtocolOregonTest.cpp` | Oregon Scientific sensor protocol decode — temperature and sensor ID from EA4C frames | None |
| `ProtocolSartanoTest` | `telldus-core/tests/service/ProtocolSartanoTest.cpp` | Sartano protocol decode — codeswitch code and method from raw data | None |
| `ProtocolX10Test` | `telldus-core/tests/service/ProtocolX10Test.cpp` | X10 protocol decode — house/unit/method extraction from 32-bit raw data | None |

### Why These Are Unit Tests

Every test above instantiates a protocol object (or calls a static decode method), passes a synthetic `ControllerMessage` with hard-coded hex data, and asserts the decoded string matches an expected command or sensor string. No USB device, serial port, socket, or configuration file is accessed. These tests validate radio-protocol bit-packing and unpacking logic in isolation.

---

## Integration Tests

There are **no integration tests in the current CppUnit suite**. All existing CppUnit tests are unit tests as defined above.

### Future Integration Tests (Phase 7 Hardware Verification)

When a TellStick Duo is connected, the following integration-test categories are planned:

| Category | Description | Example Verification |
|----------|-------------|----------------------|
| **USB Detection** | Verify `libftdi` can open the TellStick Duo VID/PID | `telldusd` logs "controller connected" on startup |
| **Device On/Off** | Send `turnon` / `turnoff` via `tdtool` and confirm RF transmission | Oscilloscope or receiving device state change |
| **Config Loading** | Parse an existing `/etc/tellstick.conf` and match device list | `tdtool --list` output matches config file entries |
| **Sensor Reception** | Receive live Oregon Scientific sensor data | `tdtool --list-sensors` shows temp/humidity readings |
| **Daemon Lifecycle** | Start, stop, and restart `telldus-core` service | No crash, config preserved, clients reconnect |
| **Docker Passthrough** | Container with `--device` and bind-mounted config behaves like native | Same `tdtool` output inside and outside container |

---

## Running the Unit Tests

### Reconfigure with tests enabled

```bash
cmake --preset headless
```

The `headless` preset already sets `ENABLE_TESTING: TRUE`.

### Build the test runner

```bash
cmake --build build/headless --target TestRunner
```

### Run via CTest

```bash
ctest --test-dir build/headless -R cppunit --output-on-failure
```

### Run directly

```bash
./build/headless/tests/TestRunner
```

Expected output:

```
StringsTest::formatfTest : OK
ProtocolEverflourishTest::decodeDataTest : OK
ProtocolHastaTest::decodeDataTest : OK
ProtocolNexaTest::decodeDataTest : OK
ProtocolOregonTest::decodeDataTest : OK
ProtocolSartanoTest::decodeDataTest : OK
ProtocolX10Test::decodeDataTest : OK
OK (7)
```

---

## Notes

- **Style tests (cpplint) and static analysis (cppcheck)** are disabled from CTest in the headless preset. They can be re-enabled by uncommenting the `ADD_SOURCES` and `ADD_TEST(cppcheck ...)` lines in `telldus-core/tests/CMakeLists.txt`.
- The test runner does **not** require a TellStick Duo to be connected.
- No test uses the real `Settings`/`DeviceManager` service layer; they test protocol classes directly.
