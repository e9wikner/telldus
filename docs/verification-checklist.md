# TellStick Duo Hardware Verification Checklist

**Phase 7: TellStick Duo Hardware Verification**
**Phase 14: MQTT Bridge Hardware Verification and Operator Documentation** (Tests 8-11)
**Version:** 1.1
**Date:** 2026-09-04

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

## Test 8: MQTT Bridge Startup and Discovery (Phase 14)

**Objective:** Confirm `telldus-mqtt` connects and publishes Home Assistant discovery

**Prerequisites:**
- A reachable MQTT broker (and a Home Assistant instance subscribed to the discovery prefix, if verifying HA end-to-end)
- Container running with `MQTT_BROKER_HOST` set (see [QUICKSTART.md](../QUICKSTART.md#mqtt--home-assistant-bridge))

**Steps:**

1. Start (or restart) the container in bridge mode, then check logs:
   ```bash
   docker logs telldus --tail 30
   ```
2. Subscribe to everything the bridge publishes:
   ```bash
   mosquitto_sub -h <broker> -t 'telldus/#' -v &
   mosquitto_sub -h <broker> -t 'homeassistant/+/telldus/+/config' -v
   ```
3. In Home Assistant (if available), check Settings → Devices & Services → MQTT for the new entities.

**Expected Results:**
- `telldus/bridge/status` is retained `online`
- One retained discovery payload (`homeassistant/<component>/telldus/<id>/config`) per configured device, matching the component table in [MQTT-DESIGN.md](../.planning/MQTT-DESIGN.md)
- Entities appear in HA, grouped by device with correct name/manufacturer/model

**Pass Criteria:**
- [ ] `telldus/bridge/status` = `online`
- [ ] Discovery payload present for every configured device
- [ ] Entities visible in Home Assistant (if HA available)

---

## Test 9: Device Command via MQTT (Phase 14)

**Objective:** Confirm a command sent over MQTT actuates the real device and updates retained state

**Steps:**

1. Publish a command (replace `<id>` with a real device ID):
   ```bash
   mosquitto_pub -h <broker> -t 'telldus/device/<id>/set' -m 'ON'
   ```
2. Confirm the physical device responded, then check both the retained MQTT
   state and `tdtool` agree:
   ```bash
   mosquitto_sub -h <broker> -t 'telldus/device/<id>/state' -C 1
   docker exec telldus tdtool --list
   ```

**Expected Results:**
- Physical device turns on
- `telldus/device/<id>/state` reads `ON`
- `tdtool --list` shows the same last-sent state

**Pass Criteria:**
- [ ] Physical device actuated
- [ ] MQTT retained state matches `tdtool --list`

---

## Test 10: Sensor Events via MQTT (Phase 14, gated on Phase 9)

**Objective:** Confirm a received sensor reading is published with correct discovery

**Prerequisites:** Phase 9 established the Duo receives sensor packets. Skip
this test (mark N/A) if Phase 9 found no receivable sensors in this
deployment.

**Steps:**

1. Wait for a sensor transmission (temperature/humidity sensors typically
   transmit every 30-90 seconds), watching:
   ```bash
   mosquitto_sub -h <broker> -t 'telldus/sensor/#' -v
   ```
2. Confirm a matching discovery payload appeared at
   `homeassistant/sensor/telldus/<protocol>_<model>_<id>_<datatype>/config`.

**Expected Results:**
- A retained value appears at `telldus/sensor/<protocol>/<model>/<id>/<datatype>`
- A matching HA discovery payload appeared on first sighting, with the
  correct `device_class`/`unit_of_measurement` for that datatype

**Pass Criteria:**
- [ ] Sensor state topic received a value
- [ ] Discovery payload present with correct unit/device_class
- [ ] N/A — no receivable sensors in this deployment (per Phase 9)

---

## Test 11: Restart Matrix — Retained State and LWT (Phase 14)

**Objective:** Confirm retained state and the Last Will survive real restarts

**Steps:**

1. **Bridge container restart:** `docker restart telldus`, then confirm
   `telldus/bridge/status` goes `offline` (LWT or clean shutdown publish)
   then back to `online`, and discovery/state are republished.
2. **Broker restart:** restart the MQTT broker, then confirm the bridge
   reconnects on its own (`mosquitto_reconnect_delay_set` backoff) and
   republishes discovery + state without a container restart.
3. **Home Assistant restart:** restart HA, then confirm entities reappear
   without manual intervention (HA re-subscribes and reads retained state).

⚠️ Broker and HA restarts affect every other client on that broker/HA
instance — coordinate with whoever else depends on them before running this
step outside a dedicated test environment.

**Pass Criteria:**
- [ ] Bridge container restart: status flips offline → online, discovery/state republished
- [ ] Broker restart: bridge reconnects unattended, discovery/state republished
- [ ] HA restart: entities reappear without manual reconfiguration

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
**MQTT Broker:** ☐ Available  ☐ Not Available  
**Home Assistant:** ☐ Available  ☐ Not Available

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
| 8 | MQTT Bridge Startup and Discovery | ☐ PASS ☐ FAIL ☐ N/A | |
| 9 | Device Command via MQTT | ☐ PASS ☐ FAIL ☐ N/A | Device ID: ___ |
| 10 | Sensor Events via MQTT | ☐ PASS ☐ FAIL ☐ N/A | Gated on Phase 9 |
| 11 | Restart Matrix (Retained State/LWT) | ☐ PASS ☐ FAIL ☐ N/A | |

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
- [MQTT-DESIGN.md](../.planning/MQTT-DESIGN.md) - MQTT bridge design, topic scheme, and Phase 8-14 breakdown
