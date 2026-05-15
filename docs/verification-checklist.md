# TellStick Duo Hardware Verification Checklist

**Phase 7: TellStick Duo Hardware Verification**  
**Version:** 1.0  
**Date:** 2026-05-15

---

## Prerequisites

Before starting verification, ensure the following are in place:

### Hardware
- [ ] TellStick Duo connected to USB port
- [ ] USB cable in good condition
- [ ] At least one 433 MHz device configured and paired

### Software
- [ ] Docker installed and running (`docker --version`)
- [ ] telldus:latest Docker image built (`docker images | grep telldus`)
- [ ] tellstick.conf exists on host with at least one device configured
- [ ] Docker permissions for current user

### Files
- [ ] `scripts/run-telldus.sh` present and configured
- [ ] `scripts/verify-usb-detection.sh` present and executable
- [ ] `scripts/verify-tellstick-hardware.sh` present and executable

---

## Test 1: Container Startup

**Objective:** Start container with proper USB passthrough

**Prerequisites:**
- Docker running
- tellstick.conf exists at known path

**Steps:**

1. Configure your tellstick.conf path:
   ```bash
   export CONFIG_PATH="/path/to/your/tellstick.conf"
   ```

2. Start the container:
   ```bash
   docker run -d \
     --name telldus \
     --privileged \
     --restart unless-stopped \
     -v "${CONFIG_PATH}:/etc/tellstick.conf:ro" \
     -v telldus-state:/var/lib/telldus \
     telldus:latest
   ```

3. Verify container is running:
   ```bash
   docker ps | grep telldus
   ```

**Expected Results:**
- Container shows status "Up"
- No immediate exits or restarts
- Container name is "telldus"

**Pass Criteria:**
- [ ] Container appears in `docker ps` output
- [ ] Status shows "Up X seconds"

**Troubleshooting:**
- If container exits immediately: Check `docker logs telldus` for config errors
- If permission denied: Verify user has docker group membership

---

## Test 2: USB Device Detection

**Objective:** Verify TellStick Duo visible in container (DUO-01)

**Prerequisites:**
- Container running
- TellStick Duo physically connected

**Steps:**

1. Check USB detection in container:
   ```bash
   docker exec telldus lsusb | grep "1781:0c31"
   ```

2. Or run automated verification:
   ```bash
   ./scripts/verify-usb-detection.sh
   ```

**Expected Results:**
- Output contains: "ID 1781:0c31 Multiple Vendors Telldus TellStick Duo"
- Exit code 0 from automated script

**Pass Criteria:**
- [ ] lsusb shows TellStick Duo
- [ ] VID:PID matches 1781:0c31

**Troubleshooting:**
- Not detected: Check USB cable, try different port
- Verify --privileged flag was used
- Check host detection: `lsusb | grep 1781:0c31`

---

## Test 3: Device Listing (DUO-03)

**Objective:** List configured devices from tellstick.conf

**Prerequisites:**
- USB detection passing
- tellstick.conf contains devices

**Steps:**

1. List devices:
   ```bash
   docker exec telldus tdtool --list
   ```

2. Verify exit code:
   ```bash
   docker exec telldus tdtool --list
echo "Exit code: $?"
   ```

**Expected Results:**
- Shows "Number of devices: N" where N > 0
- Lists each device with ID, name, and type
- Exit code is 0

**Example Output:**
```
Number of devices: 2
1	Living Room Lamp
2	Bedroom Light
```

**Pass Criteria:**
- [ ] Device count > 0
- [ ] Device names match config
- [ ] Exit code 0

**Troubleshooting:**
- Zero devices: Verify tellstick.conf is mounted correctly
- Check config syntax: `docker exec telldus cat /etc/tellstick.conf`

---

## Test 4: On Command (DUO-04)

**Objective:** Transmit ON command to device

**Prerequisites:**
- Device listing working
- Physical device available for observation

**Steps:**

1. Choose a device to test (default: ID 1):
   ```bash
   docker exec telldus tdtool --on 1
   ```

2. Verify exit code:
   ```bash
   docker exec telldus tdtool --on 1
echo "Exit code: $?"
   ```

3. **Physically observe the device** - confirm it turns ON

**Expected Results:**
- Output: "Turning on device X, Device Name - Success"
- Exit code: 0
- Device physically turns ON

**Pass Criteria:**
- [ ] Exit code 0
- [ ] Success message displayed
- [ ] Device physically responds (manual verification)

**⚠️ Important:** 433 MHz is one-way communication. Exit code 0 means "command transmitted" NOT "device acknowledged." Physical verification is required.

**Troubleshooting:**
- Exit code 3: Device ID not found - verify device exists in listing
- Device doesn't respond: Check batteries/power, pairing, distance

---

## Test 5: Off Command (DUO-04)

**Objective:** Transmit OFF command to device

**Prerequisites:**
- On command test completed
- Device is currently ON

**Steps:**

1. Send OFF command:
   ```bash
   docker exec telldus tdtool --off 1
   ```

2. Verify exit code:
   ```bash
   docker exec telldus tdtool --off 1
echo "Exit code: $?"
   ```

3. **Physically observe the device** - confirm it turns OFF

**Expected Results:**
- Output: "Turning off device X, Device Name - Success"
- Exit code: 0
- Device physically turns OFF

**Pass Criteria:**
- [ ] Exit code 0
- [ ] Success message displayed
- [ ] Device physically responds (manual verification)

**Note:** Per D-07-10, complete on→off cycle is required for full verification.

---

## Test 6: Automated Verification (Optional)

**Objective:** Run automated verification script

**Prerequisites:**
- All previous tests passing

**Steps:**

1. Run automated script:
   ```bash
   ./scripts/verify-tellstick-hardware.sh
   ```

2. Or with summary output:
   ```bash
   ./scripts/verify-tellstick-hardware.sh --summary
   ```

**Expected Results:**
- All automated tests pass
- Manual verification section displayed
- Summary shows PASS for USB, listing, commands

**Pass Criteria:**
- [ ] USB detection: PASS
- [ ] Device listing: PASS
- [ ] On/Off commands: PASS

**Note:** Automated tests verify transmission only. Physical device response must be verified manually.

---

## Test 7: Error Path Verification (Optional)

**Objective:** Verify graceful error handling

**Prerequisites:**
- Container running

**Steps:**

1. Test invalid device ID:
   ```bash
   docker exec telldus tdtool --on 999
echo "Exit code: $?"
   ```

2. Run error path script:
   ```bash
   ./scripts/verify-error-paths.sh
   ```

**Expected Results:**
- Invalid device returns non-zero exit code (3)
- Error path script shows PASS for error scenarios

**Pass Criteria:**
- [ ] Invalid device returns error
- [ ] Error code 3 (TELLSTICK_ERROR_DEVICE_NOT_FOUND)

---

## Sign-Off

I have completed the hardware verification checklist and confirm:

### Tester Information

**Tester Name:** _________________________________  
**Date:** _________________________________  
**Organization:** _________________________________

### Environment Details

**Host OS:** _________________________________  
**Docker Version:** _________________________________  
**TellStick Duo:** ☐ Connected  ☐ Not Available  
**Hardware Location:** ☐ Native Arch  ☐ Raspberry Pi  ☐ Other: _______

### Test Results

| Test # | Description | Result | Notes |
|--------|-------------|--------|-------|
| 1 | Container Startup | ☐ PASS ☐ FAIL ☐ N/A | |
| 2 | USB Detection (DUO-01) | ☐ PASS ☐ FAIL ☐ N/A | |
| 3 | Device Listing (DUO-03) | ☐ PASS ☐ FAIL ☐ N/A | |
| 4 | On Command (DUO-04) | ☐ PASS ☐ FAIL ☐ N/A | Device ID: ___ |
| 5 | Off Command (DUO-04) | ☐ PASS ☐ FAIL ☐ N/A | |
| 6 | Automated Verification | ☐ PASS ☐ FAIL ☐ N/A | |
| 7 | Error Path Verification | ☐ PASS ☐ FAIL ☐ N/A | Optional |

### Overall Status

☐ **ALL TESTS PASSED** - Hardware verification complete  
☐ **MINOR ISSUES** - Functional with notes (see below)  
☐ **TESTS FAILED** - Requires investigation

### Notes and Issues

_____________________________________________________________________________  
_____________________________________________________________________________  
_____________________________________________________________________________  
_____________________________________________________________________________

### Final Sign-Off

**Tester Signature:** _________________________________  
**Date:** _________________________________

---

## Quick Reference

### Common Docker Commands

```bash
# Start container
./scripts/run-telldus.sh

# Check status
docker ps | grep telldus

# View logs
docker logs telldus --tail 20

# Stop container
docker stop telldus && docker rm telldus

# Restart container
docker restart telldus
```

### Common tdtool Commands

```bash
# List devices
docker exec telldus tdtool --list

# Turn device on
docker exec telldus tdtool --on <device_id>

# Turn device off
docker exec telldus tdtool --off <device_id>

# Get help
docker exec telldus tdtool --help
```

### Verification Scripts

```bash
# USB detection only
./scripts/verify-usb-detection.sh

# Full hardware verification
./scripts/verify-tellstick-hardware.sh

# Error path testing
./scripts/verify-error-paths.sh

# CI mode (no hardware required)
./scripts/verify-tellstick-hardware.sh --error-only
```

### Log Access

```bash
# View recent logs
docker logs telldus --tail 50

# Follow logs in real-time
docker logs telldus -f

# Check daemon process
docker exec telldus pgrep telldusd
```

---

## Troubleshooting Guide

### USB Not Detected

| Check | Command |
|-------|---------|
| Host detection | `lsusb \| grep 1781:0c31` |
| Container detection | `docker exec telldus lsusb \| grep 1781:0c31` |
| Privileged flag | `docker inspect telldus \| grep Privileged` |
| USB cable | Try different cable/port |

### Device Commands Fail

| Symptom | Check | Solution |
|---------|-------|----------|
| Exit code 1 | Device ID exists | Run `tdtool --list` to get valid IDs |
| Exit code 3 | Device in config | Check `tellstick.conf` syntax |
| Exit code 6 | Daemon running | Check `docker logs telldus` |
| Device no response | Physical state | Check power, pairing, batteries |

### Container Issues

| Issue | Diagnostic | Solution |
|-------|------------|----------|
| Won't start | `docker logs telldus` | Check config file path |
| Exits immediately | `docker ps -a` | Verify config file exists |
| Permission denied | `groups` | Add user to docker group |

---

## References

- [Hardware Verification Guide](./hardware-verification.md) - Full technical documentation
- [Docker Runtime Guide](./docker-runtime.md) - Container setup and management
- [Phase 7 Research](../.planning/phases/07-tellstick-duo-hardware-verification/07-RESEARCH.md) - Technical details
- [Phase 7 Context](../.planning/phases/07-tellstick-duo-hardware-verification/07-CONTEXT.md) - Implementation decisions
