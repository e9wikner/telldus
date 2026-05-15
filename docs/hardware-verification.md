# TellStick Duo Hardware Verification

**Phase 7: TellStick Duo Hardware Verification**

This document provides comprehensive hardware verification procedures for the TellStick Duo on modern Linux systems using Docker. It covers USB detection, device command verification, and error path testing.

## Overview

This guide validates that the modernized Telldus Core runtime can properly detect and communicate with the TellStick Duo hardware. Per decision D-07-03, Docker is the primary verification target for Phase 7.

### Scope

**In Scope:**
- USB device detection (DUO-01)
- Device listing from configuration (DUO-03)
- On/off command transmission (DUO-04)
- Error path verification (D-07-11)

**Out of Scope (per locked decisions):**
- Dimming commands (DUO-05) - per D-07-08
- Sensor/receive path (DUO-06) - per D-07-04
- Native Arch Linux verification - per D-07-03

### Prerequisites

Before proceeding with verification, ensure you have:

**Hardware:**
1. TellStick Duo physically connected to USB
2. At least one 433 MHz device paired and configured
3. USB cable in good condition

**Software:**
1. Docker installed and running
2. telldus:latest Docker image built
3. tellstick.conf exists on host with configured devices
4. Docker permissions for current user

**Files:**
- `scripts/run-telldus.sh` configured with your config path
- `scripts/verify-usb-detection.sh` present and executable
- `scripts/verify-tellstick-hardware.sh` present and executable

## USB Detection Verification

The TellStick Duo uses USB Vendor ID (VID) 0x1781 and Product ID (PID) 0x0C31.

### Prerequisites

- TellStick Duo physically connected to USB
- Container running with `--privileged` flag (required for USB access per D-06-01)

### Verification Command

Check that the TellStick Duo is visible in the container:

```bash
docker exec telldus lsusb | grep "1781:0c31"
```

### Expected Output

```
Bus 001 Device 005: ID 1781:0c31 Multiple Vendors Telldus TellStick Duo
```

The output should include:
- `1781:0c31` - VID:PID of TellStick Duo
- `Telldus TellStick Duo` - Device description

### Automated Verification

Use the provided verification script:

```bash
./scripts/verify-usb-detection.sh [container_name]
```

The script will:
1. Check if the container is running
2. Verify TellStick Duo is detected via USB
3. Test error paths when hardware is not connected
4. Provide pass/fail results for each test

### Troubleshooting USB Detection

If the TellStick Duo is not detected:

1. **Check USB cable connection**
   ```bash
   # On the host
   lsusb | grep 1781:0c31
   ```

2. **Verify container has --privileged flag**
   ```bash
   docker inspect telldus | grep -A5 '"Privileged"'
   ```
   Should show: `"Privileged": true`

3. **Try different USB port**
   - Some USB hubs may have compatibility issues
   - Direct motherboard ports are preferred

4. **Check container logs**
   ```bash
   docker logs telldus --tail 50
   ```

5. **Restart container**
   ```bash
   docker restart telldus
   ```

## Device Command Verification

This section covers device listing (DUO-03) and on/off command verification (DUO-04).

### Prerequisites

- TellStick Duo detected via USB (previous section)
- tellstick.conf contains at least one configured device
- Container is running with config file mounted

### Device Listing (DUO-03)

List all configured devices from tellstick.conf:

```bash
docker exec telldus tdtool --list
```

#### Expected Output

```
Number of devices: 2
1	Living Room Lamp
2	Bedroom Light
```

The output shows:
- Total number of configured devices
- Device ID and name for each device

#### Exit Code Behavior

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success - devices listed |
| Non-zero | Error (daemon not running, config error, etc.) |

### On/Off Commands (DUO-04)

Transmit on/off commands to a device. Per D-07-09, testing one representative device is sufficient. The default device ID is 1 (first device in config).

#### Turn Device ON

```bash
docker exec telldus tdtool --on 1
```

#### Turn Device OFF

```bash
docker exec telldus tdtool --off 1
```

#### Expected Output

```
Turning on device 1, Living Room Lamp - Success
```

Or for failure:
```
Turning on device 1, Living Room Lamp - Error
```

#### Exit Code Verification

Per D-07-02, verify exit codes:

```bash
docker exec telldus tdtool --on 1
echo "Exit code: $?"  # Should be 0 for success
```

### 433 MHz One-Way Communication Warning

⚠️ **IMPORTANT**: 433 MHz is a one-way communication protocol.

- Exit code 0 means "command transmitted successfully"
- Exit code 0 does NOT mean "device acknowledged the command"
- There is no feedback from the device to confirm it received the command
- **Physical verification is required** to confirm the device actually responded

To verify device response:
1. Watch the physical device when sending ON command
2. Confirm it turns on (light illuminates, switch engages, etc.)
3. Watch when sending OFF command
4. Confirm it turns off

### Automated Verification

Run the main hardware verification script:

```bash
# Test default device (ID 1)
./scripts/verify-tellstick-hardware.sh

# Test specific device
./scripts/verify-tellstick-hardware.sh telldus 2
```

The script performs:
1. USB detection check
2. Device listing verification
3. ON/OFF command test sequence
4. Exit code verification

### Command Reference

| Command | Description | Example |
|---------|-------------|---------|
| `--list` | List all devices | `docker exec telldus tdtool --list` |
| `--on <id>` | Turn device ON | `docker exec telldus tdtool --on 1` |
| `--off <id>` | Turn device OFF | `docker exec telldus tdtool --off 1` |

### Scope Limitations

Per locked decisions:
- **Dimming (DUO-05)**: Out of scope - per D-07-08, dimming commands are not covered in Phase 7
- **Bell/Learn commands**: Out of scope - per D-07-08
- **Sensor/Receive (DUO-06)**: Out of scope - per D-07-04, deferred to v1.x or v2

## Error Path Verification

Per D-07-11, error path verification ensures graceful failure when hardware is not connected or invalid commands are issued. This is essential for CI/testing environments and operator troubleshooting.

### Error Scenarios

#### 1. No Hardware Connected

When TellStick Duo is not physically connected, tdtool commands should return non-zero exit codes:

```bash
docker exec telldus tdtool --list
echo "Exit code: $?"  # Should be non-zero
```

#### 2. Invalid Device ID

Attempting to control a non-existent device:

```bash
docker exec telldus tdtool --on 999
echo "Exit code: $?"  # Should be 3 (TELLSTICK_ERROR_DEVICE_NOT_FOUND)
```

#### 3. Daemon Not Running

When telldusd is not running or container is stopped:

```bash
docker exec stopped-container tdtool --list
echo "Exit code: $?"  # Should be non-zero
```

### Exit Code Reference

| Code | Constant | Meaning |
|------|----------|---------|
| 0 | TELLSTICK_SUCCESS | Command successful |
| 1 | TELLSTICK_ERROR_NOT_FOUND | Device/method not found |
| 2 | TELLSTICK_ERROR_PERMISSION_DENIED | Permission denied |
| 3 | TELLSTICK_ERROR_DEVICE_NOT_FOUND | Device ID not found |
| 4 | TELLSTICK_ERROR_METHOD_NOT_SUPPORTED | Method not supported |
| 5 | TELLSTICK_ERROR_COMMUNICATION | Communication error |
| 6 | TELLSTICK_ERROR_CONNECTING_SERVICE | Cannot connect to service |
| 7 | TELLSTICK_ERROR_UNKNOWN_RESPONSE | Unknown response from device |
| 8 | TELLSTICK_ERROR_SYNTAX | Command syntax error |
| 9 | TELLSTICK_ERROR_BROKEN_PIPE | Broken pipe |
| 10 | TELLSTICK_ERROR_COMMUNICATING_SERVICE | Service communication error |
| 11 | TELLSTICK_ERROR_CONFIG_SYNTAX | Configuration syntax error |
| 99 | TELLSTICK_ERROR_UNKNOWN | Unknown error |

### Automated Error Verification

Run the dedicated error path verification script:

```bash
./scripts/verify-error-paths.sh [container_name]
```

This script tests:
1. No hardware error path
2. Invalid device ID error
3. Daemon connection error
4. Malformed command handling

### CI Testing Without Hardware

For automated testing environments without physical TellStick hardware:

```bash
# Run only error path tests
./scripts/verify-tellstick-hardware.sh --error-only

# Or use the dedicated error script
./scripts/verify-error-paths.sh
```

These modes validate error handling without requiring hardware connection.

## Automated vs Manual Verification

This phase provides both automated scripts and manual procedures for comprehensive verification.

### Automated Verification

Use the verification scripts for quick, repeatable testing:

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `verify-usb-detection.sh` | USB detection only | Initial setup, USB troubleshooting |
| `verify-tellstick-hardware.sh` | Full verification | Complete hardware validation |
| `verify-error-paths.sh` | Error handling | CI/testing environments |

**Example:**
```bash
# Quick automated test
./scripts/verify-tellstick-hardware.sh

# With summary output
./scripts/verify-tellstick-hardware.sh --summary

# CI mode (no hardware required)
./scripts/verify-tellstick-hardware.sh --error-only
```

### Manual Verification

Use the manual checklist for:
- First-time setup validation
- Operator sign-off procedures
- Detailed step-by-step testing
- Documentation of test results

**Reference:** [verification-checklist.md](verification-checklist.md) - Complete manual checklist with sign-off table

### Which to Choose?

- **Development/CI**: Use automated scripts with `--error-only` flag
- **Initial Setup**: Run automated scripts, then complete manual checklist
- **Production Sign-Off**: Complete manual checklist with sign-off
- **Troubleshooting**: Use specific scripts (USB, error paths) as needed

## Quick Start

### Option 1: Automated (Fastest)

```bash
# Start the container (if not running)
CONFIG_PATH=/path/to/tellstick.conf ./scripts/run-telldus.sh

# Run complete automated verification
./scripts/verify-tellstick-hardware.sh
```

### Option 2: Manual Step-by-Step

```bash
# 1. Start container
CONFIG_PATH=/path/to/tellstick.conf ./scripts/run-telldus.sh

# 2. Verify USB detection
docker exec telldus lsusb | grep "1781:0c31"

# 3. List devices
docker exec telldus tdtool --list

# 4. Test device (replace 1 with your device ID)
docker exec telldus tdtool --on 1
docker exec telldus tdtool --off 1
```

### Option 3: Complete Manual Checklist

Follow the comprehensive [verification-checklist.md](verification-checklist.md) for:
- Detailed test procedures
- Pass/fail criteria
- Sign-off documentation
- Troubleshooting guidance

## Related Documentation

- [Verification Checklist](verification-checklist.md) - Step-by-step manual verification
- [Docker Runtime](docker-runtime.md) - Container setup and management
- [Phase 7 Verification Report](../.planning/phases/07-tellstick-duo-hardware-verification/07-04-VERIFICATION.md) - Phase completion verification

## Summary

This document provides USB detection verification procedures for the TellStick Duo hardware. The automated verification scripts and manual procedures ensure proper hardware integration with the containerized Telldus Core runtime.

**Requirements covered:**
- DUO-01: USB detection
- DUO-03: Device listing
- DUO-04: On/off command transmission

**Requirements deferred to v1.x/v2:**
- DUO-05: Dimming commands (per D-07-08)
- DUO-06: Sensor/receive path (per D-07-04)

**Next:** Phase 8 - Operator Documentation
