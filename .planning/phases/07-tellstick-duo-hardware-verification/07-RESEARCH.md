# Phase 07: TellStick Duo Hardware Verification - Research

**Researched:** 2026-05-15
**Domain:** Containerized hardware verification, USB passthrough, shell-based testing
**Confidence:** HIGH

## Summary

Phase 7 validates that the modernized Telldus Core runtime controls real TellStick Duo hardware through Docker containers with USB passthrough. This research identifies the technical patterns for:

1. **USB Device Passthrough** - Docker `--privileged` mode vs `--device` flags for FTDI USB access
2. **Verification Patterns** - Shell script structures for checklist-based vs executable verification
3. **Error Code Mapping** - tdtool exit codes and Telldus Core error constants for success/failure detection
4. **Command Verification** - Transmission-only verification (return codes) vs response verification

**Primary recommendation:** Use a hybrid approach: an executable shell script for automated verification (device listing, error paths) combined with a manual checklist for hardware-specific steps (visual confirmation of device state). USB passthrough requires `--privileged` mode in v1, with `--device` as a documented alternative for production hardening.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-07-01:** Minimum viable verification is "tdtool lists configured devices"
- **D-07-02:** Phase 7 v1 scope includes command transmission test: tdtool --on/--off returns exit code 0 (TELLSTICK_SUCCESS)
- **D-07-03:** Success criteria is Docker as primary target. Native Arch verification is explicitly not required for Phase 7 complete
- **D-07-04:** Sensor/receive path verification, long-running soak tests, and comprehensive protocol testing are deferred to v1.x or v2
- **D-07-05:** Docker container with USB passthrough is the primary and only required verification target
- **D-07-06:** Single container test is sufficient for Phase 7. No restart/resilience testing or long-running soak tests required
- **D-07-07:** Both `docker exec` from host and interactive shell inside container are acceptable methods for running tdtool commands
- **D-07-08:** Verify on/off commands only (TELLSTICK_TURNON / TELLSTICK_TURNOFF). Dimming, bell, and learn commands are out of scope for Phase 7
- **D-07-09:** Test one representative device from the tellstick.conf. Testing all devices or multiple protocols is not required
- **D-07-10:** Verification procedure: turn on → verify success → turn off → verify success. Full cycle confirms both directions work
- **D-07-11:** When TellStick Duo is not physically connected, verify error paths: tdtool returns TELLSTICK_ERROR_NOT_FOUND or similar error codes
- **D-06-01:** Use `--privileged` mode for USB passthrough in v1 (from Phase 6)
- **D-06-04:** Use `docker exec` pattern as the primary communication method

### Agent's Discretion
- The agent may structure the verification as a manual checklist, shell script, or combination
- The agent may choose which specific device ID to test (first device in config, random selection, or parameterized)
- The agent may include optional diagnostic logging or debug output to help troubleshoot failures

### Deferred Ideas (OUT OF SCOPE)
- Sensor/receive path verification — Testing sensor decoding and raw event reception
- Dimming command verification — TELLSTICK_DIM with dimlevel parameter
- Bell and learn commands — TELLSTICK_BELL and TELLSTICK_LEARN methods
- Native Arch verification — Docker is the supported path
- Long-running soak tests — Stability testing over hours/days
- RF packet analysis — Using RTL-SDR to verify actual RF transmission
- Raspberry Pi hardware verification — Docker on arm64 implies Pi compatibility
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DUO-01 | Operator can connect a TellStick Duo and have the Linux daemon detect it over USB | USB passthrough with `--privileged`; libftdi opens by VID/PID (0x1781/0x0C31); detection visible in daemon logs |
| DUO-03 | Operator can list configured devices from the existing `tellstick.conf` using `tdtool` | `docker exec <container> tdtool --list` pattern; returns device count and names; exit code 0 on success |
| DUO-04 | Operator can switch existing configured devices on and off using `tdtool` | `tdtool --on <id>` and `tdtool --off <id>`; returns TELLSTICK_SUCCESS (0) on transmission success; verify with `tdtool --list` state change |
| DUO-05 | Operator can dim existing configured devices that support dimming using `tdtool` | OUT OF SCOPE per D-07-08 — deferred to v1.x |
| DUO-06 | Operator can observe raw device or sensor events from the TellStick Duo | OUT OF SCOPE per D-07-04 — requires sensor hardware; deferred |
| DOCS-04 | Operator has a concise manual verification checklist for TellStick Duo behavior | Executable script for automated checks + manual checklist for hardware steps |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| USB Device Detection | Host OS | Container | libftdi requires access to `/dev/bus/usb` and USB device descriptors; container runtime delegates to host USB subsystem |
| FTDI Communication | Container (telldusd) | — | telldusd inside container uses libftdi1 to open TellStick by VID/PID |
| Command Execution | Container (tdtool) | — | tdtool runs via `docker exec`, connects to telldusd via Unix sockets |
| Device State Tracking | Container (telldusd) | Volume persistence | Runtime state in `/var/lib/telldus/telldus-core.conf` survives container restart |
| Verification Script | Host | — | Operator runs verification script from host, which orchestrates container commands |

## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| Docker Engine | 24.x+ | Container runtime | Established in Phases 5-6; proven with multi-arch builds |
| libftdi1 | 1.5-7 (Debian) | FTDI USB communication | Native library for TellStick USB access; opens by VID/PID |
| tdtool | Built from source | CLI device control | The existing control surface; returns exit codes for verification |
| telldusd | Built from source | Daemon service | Runs in container; handles USB detection and device commands |
| lsusb | usbutils package | USB device enumeration | Standard Linux tool for listing USB devices |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| docker exec | Docker CLI 24.x+ | Execute commands in running container | Primary pattern for tdtool invocation |
| bash | 5.x | Verification script shell | For complex verification logic with error handling |
| grep | POSIX | Pattern matching | Filter tdtool output, check USB presence |

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          Host OS                                 │
│  ┌──────────────────┐  ┌─────────────────────────────────────┐  │
│  │ Operator Shell   │  │ Docker Engine                       │  │
│  │ (verification.sh)│  │                                     │  │
│  └────────┬─────────┘  │  ┌─────────────────────────────┐   │  │
│           │            │  │ telldus Container           │   │  │
│           │ docker exec│  │                             │   │  │
│           ├────────────┼──┼─> ┌─────────────────────┐   │   │  │
│           │            │  │   │ tdtool (exec'd)     │   │   │  │
│           │            │  │   └──────────┬──────────┘   │   │  │
│           │            │  │              │              │   │  │
│           │            │  │   ┌──────────▼──────────┐   │   │  │
│           │            │  │   │ Unix Socket         │   │   │  │
│           │            │  │   │ /tmp/TelldusClient  │   │   │  │
│           │            │  │   └──────────┬──────────┘   │   │  │
│           │            │  │              │              │   │  │
│           │            │  │   ┌──────────▼──────────┐   │   │  │
│           │            │  │   │ telldusd (PID 1)    │   │   │  │
│           │            │  │   │                     │   │   │  │
│           │            │  │   │ ┌─────────────────┐ │   │   │  │
│           │            │  │   │ │ ControllerManager│ │   │   │  │
│           │            │  │   │ └────────┬────────┘ │   │   │  │
│           │            │  │   │          │          │   │   │  │
│           │            │  │   │   ┌──────▼──────┐   │   │   │  │
│           │            │  │   │   │ libftdi1    │   │   │   │  │
│           │            │  │   │   └──────┬──────┘   │   │   │  │
│           │            │  │   └──────────┼──────────┘   │   │  │
│           │            │  └──────────────┼──────────────┘   │  │
│           │            │                 │                  │  │
│           │            │  USB Passthrough│ (/dev/bus/usb)   │  │
│           │            └─────────────────┼──────────────────┘  │
│           │                              │                      │
│           │            ┌─────────────────▼──────────────────┐  │
│           │            │    TellStick Duo (USB)             │  │
│           │            │    VID: 0x1781, PID: 0x0C31        │  │
│           │            └────────────────────────────────────┘  │
│           │                                                    │
│           └────────────────────────────────────────────────────┘
│
│  USB Device Path: Host /dev/bus/usb --> Container /dev/bus/usb
│  Config Mount: Host /path/to/tellstick.conf --> Container /etc/tellstick.conf
│  State Volume: Host volume --> Container /var/lib/telldus
└─────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
scripts/
├── verify-tellstick-hardware.sh    # Main verification script
├── run-telldus.sh                  # Existing container runner
└── test-container-runtime.sh       # Existing runtime tests

.planning/phases/07-tellstick-duo-hardware-verification/
├── 07-CONTEXT.md                   # Phase decisions
├── 07-RESEARCH.md                  # This file
├── 07-PLAN-01.md                   # Plan: USB detection verification
├── 07-PLAN-02.md                   # Plan: Device listing & commands
├── 07-PLAN-03.md                   # Plan: Manual verification checklist
└── 07-PLAN-04.md                   # Plan: Documentation

docs/
└── verification-checklist.md       # Operator-facing checklist (output)
```

### Pattern 1: USB Device Detection in Containers
**What:** Using `--privileged` mode to grant USB device access
**When to use:** v1 primary deployment path; home/single-use scenarios where reliability trumps least-privilege
**Example:**
```bash
# Source: Docker documentation + Phase 6 decisions
# Run container with USB passthrough
docker run -d \
    --name telldus \
    --privileged \
    --device /dev/bus/usb \
    -v /path/to/tellstick.conf:/etc/tellstick.conf:ro \
    -v telldus-state:/var/lib/telldus \
    telldus:latest

# Verify USB detection inside container
docker exec telldus lsusb | grep "1781:0c31"
# Expected output: Bus XXX Device YYY: ID 1781:0c31 Multiple Vendors Telldus TellStick Duo
```

**Alternative (production hardening - v2):**
```bash
# More restrictive --device approach (requires udev rules)
docker run -d \
    --name telldus \
    --device /dev/tellstick:/dev/tellstick \
    -v /path/to/tellstick.conf:/etc/tellstick.conf:ro \
    telldus:latest
```

### Pattern 2: tdtool Command Verification
**What:** Using exit codes to verify command success without requiring physical device response
**When to use:** Automated testing, CI/CD, development without physical hardware
**Example:**
```bash
# Source: tdtool/main.cpp return logic
# Check device listing
if docker exec telldus tdtool --list >/dev/null 2>&1; then
    echo "Device listing: PASS"
else
    echo "Device listing: FAIL (exit code: $?)"
fi

# Check on/off command transmission
# Note: Returns 0 if command transmitted successfully
# Does NOT verify device actually turned on (would require RF sniffer or visual check)
device_id=1
if docker exec telldus tdtool --on "$device_id" >/dev/null 2>&1; then
    echo "ON command transmitted: PASS"
else
    echo "ON command: FAIL (exit code: $?)"
fi
```

### Pattern 3: Error Path Verification
**What:** Testing behavior when TellStick is not connected
**When to use:** Development testing, CI validation, documentation of expected failures
**Example:**
```bash
# Run container WITHOUT --privileged or --device
docker run -d --name telldus-no-usb telldus:latest

# Attempt device command (should fail gracefully)
docker exec telldus-no-usb tdtool --on 1
# Expected: Returns non-zero exit code
# tdtool prints error message via tdGetErrorString()

# Verify error is TELLSTICK_ERROR_NOT_FOUND (-1) or similar
exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "Error path verified: Command correctly failed without hardware"
fi
```

### Pattern 4: Hybrid Verification (Automated + Manual)
**What:** Executable script for automated checks + manual checklist for hardware steps
**When to use:** Phase 7 hardware verification where some steps require physical observation
**Example Structure:**
```bash
#!/bin/bash
# verify-tellstick-hardware.sh

# --- AUTOMATED CHECKS ---
# 1. Container running
docker ps | grep -q telldus || exit 1

# 2. USB device visible
if docker exec telldus lsusb | grep -q "1781:0c31"; then
    echo "✓ TellStick Duo USB detected"
else
    echo "✗ TellStick Duo NOT detected - check USB connection"
    exit 1
fi

# 3. Device listing works
if docker exec telldus tdtool --list >/dev/null 2>&1; then
    echo "✓ Device listing successful"
else
    echo "✗ Device listing failed"
    exit 1
fi

# 4. Command transmission
# ... automated checks continue ...

echo ""
echo "=== AUTOMATED CHECKS PASSED ==="
echo ""
echo "=== MANUAL VERIFICATION REQUIRED ==="
echo "1. Observe the physical device for device ID: <first_device_id>"
echo "2. Run: docker exec telldus tdtool --on <first_device_id>"
echo "3. Confirm device turned ON (visual check or RF sniffer)"
echo "4. Run: docker exec telldus tdtool --off <first_device_id>"
echo "5. Confirm device turned OFF"
echo "6. Mark verification complete: [ ]"
```

### Anti-Patterns to Avoid
- **Attempting to verify RF transmission without tools:** Don't try to verify the actual RF packet was sent without an RTL-SDR or similar — verify transmission success via exit codes only
- **Testing all configured devices:** Per D-07-09, testing one device is sufficient; testing all generates excessive RF traffic
- **Expecting device state feedback:** 433 MHz is one-way; the device doesn't report back its state. Only verify that tdtool reported success
- **Using `--device` without udev rules:** Without a stable `/dev/tellstick` symlink, device paths change between reboots; use `--privileged` for v1 simplicity

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| USB device detection in containers | Custom udev monitoring | `lsusb` inside container via `docker exec` | Standard tool, already available in Debian base image |
| Container health verification | Custom HEALTHCHECK | Manual `docker exec` verification script | Phase 6 deferred HEALTHCHECK to v2; manual verification is acceptable for v1 per D-06-14 |
| RF packet verification | Custom RTL-SDR decoder | Transmission verification only (exit codes) | RF analysis is complex, requires specialized hardware; deferred to v2 per deferred ideas |
| Device state tracking | Polling physical devices | `tdtool --list` lastSentCommand | Daemon tracks last command sent, not actual device state (433 MHz is one-way) |
| Shell script color output | Manual ANSI codes | tput or standard variables | More portable and handles non-terminal environments gracefully |

**Key insight:** The TellStick Duo uses 433 MHz one-way communication. You cannot verify a device actually received the command without external observation (visual, RF sniffer, power meter). The verification focuses on: (1) USB connection, (2) command transmission success (exit code), (3) daemon state tracking.

## Common Pitfalls

### Pitfall 1: Container Loses USB Access After Reboot
**What goes wrong:** Device path changes (e.g., `/dev/ttyUSB0` → `/dev/ttyUSB1`) or container restarts without `--privileged`
**Why it happens:** USB device enumeration is non-deterministic; udev rules not in place for stable symlinks
**How to avoid:** Use `--privileged` (D-06-01) which grants access to all USB devices regardless of path changes; libftdi opens by VID/PID not device path
**Warning signs:** Container logs show "Failed to open TellStick" or libftdi errors; `lsusb` inside container shows device but telldusd doesn't detect it

### Pitfall 2: tdtool Returns Success But Device Doesn't Respond
**What goes wrong:** Exit code 0 means "command transmitted" not "device acknowledged"
**Why it happens:** 433 MHz is one-way communication; no acknowledgment from device
**How to avoid:** Document this limitation clearly; verification confirms transmission only, not device state change; manual step required for physical confirmation
**Warning signs:** Operator confusion about why "verification passed" but lamp didn't turn on

### Pitfall 3: State Persistence Misunderstanding
**What goes wrong:** Expecting device state to persist across daemon restarts when no state file exists
**Why it happens:** `/var/lib/telldus/telldus-core.conf` is created only after first state-changing operation
**How to avoid:** Ensure volume is mounted; understand state file appears after first device control command
**Warning signs:** Container restart shows all devices in "Unknown state" initially

### Pitfall 4: Race Condition on Daemon Startup
**What goes wrong:** Running `tdtool --list` immediately after container start fails
**Why it happens:** telldusd takes time to start and load configuration
**How to avoid:** Add retry logic or sleep before first tdtool command; check daemon logs
**Warning signs:** Intermittent failures; "Error fetching devices" messages

### Pitfall 5: Confusing Error Codes
**What goes wrong:** Exit code confusion due to tdtool's negative return value convention
**Why it happens:** tdtool returns `-returnSuccess` (negated error code), so TELLSTICK_SUCCESS (0) becomes exit code 0, but TELLSTICK_ERROR_NOT_FOUND (-1) becomes exit code 1
**How to avoid:** Document that tdtool exit code 0 = success, non-zero = failure with specific error mapping
**Warning signs:** Scripts checking for specific exit codes getting confused by negation

## Code Examples

### USB Detection Verification
```bash
# Source: Verified against Docker runtime + TellStick hardware
#!/bin/bash

verify_usb_detection() {
    local container="${1:-telldus}"
    local vid_pid="1781:0c31"  # TellStick Duo VID:PID
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "ERROR: Container '$container' not running"
        return 1
    fi
    
    # Check for FTDI/TellStick device
    local usb_info
    usb_info=$(docker exec "$container" lsusb 2>/dev/null | grep -i "$vid_pid" || true)
    
    if [ -n "$usb_info" ]; then
        echo "PASS: TellStick Duo USB detected"
        echo "  Details: $usb_info"
        return 0
    else
        echo "FAIL: TellStick Duo not found in USB bus"
        echo "  Check: docker exec $container lsusb"
        return 1
    fi
}
```

### Device Listing Verification
```bash
# Source: Based on tdtool/main.cpp list_devices() logic
verify_device_listing() {
    local container="${1:-telldus}"
    
    # Get device list with output capture
    local device_list
    device_list=$(docker exec "$container" tdtool --list 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        local device_count
        device_count=$(echo "$device_list" | grep -c "^Number of devices:" | awk '{print $4}')
        echo "PASS: Device listing successful"
        echo "  Raw output:"
        echo "$device_list" | head -20 | sed 's/^/    /'
        return 0
    else
        echo "FAIL: Device listing failed (exit code: $exit_code)"
        echo "  Output: $device_list"
        return 1
    fi
}
```

### On/Off Command Verification (Transmission Only)
```bash
# Source: Based on tdtool/main.cpp switch_device() logic
verify_on_off_command() {
    local container="${1:-telldus}"
    local device_id="${2:-1}"  # Default to first device
    
    echo "Testing ON command for device $device_id..."
    
    # Send ON command
    local output
    output=$(docker exec "$container" tdtool --on "$device_id" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "PASS: ON command transmitted successfully"
        echo "  Output: $output"
        
        # Wait briefly for RF transmission
        sleep 1
        
        # Send OFF command
        echo "Testing OFF command for device $device_id..."
        output=$(docker exec "$container" tdtool --off "$device_id" 2>&1)
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            echo "PASS: OFF command transmitted successfully"
            echo "  Output: $output"
            return 0
        else
            echo "FAIL: OFF command failed (exit code: $exit_code)"
            echo "  Output: $output"
            return 1
        fi
    else
        echo "FAIL: ON command failed (exit code: $exit_code)"
        echo "  Output: $output"
        
        # Provide helpful error context
        if echo "$output" | grep -qi "not found"; then
            echo "  Hint: Device ID $device_id not found in tellstick.conf"
        fi
        return 1
    fi
}
```

### Error Path Verification (No Hardware)
```bash
# Source: Testing TELLSTICK_ERROR_NOT_FOUND path
verify_error_path_no_hardware() {
    local container="${1:-telldus}"
    
    echo "Verifying error handling when device not available..."
    
    # Attempt command without TellStick connected
    # This should fail gracefully with appropriate error
    local output
    output=$(docker exec "$container" tdtool --on 1 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "PASS: Command correctly failed without hardware (exit code: $exit_code)"
        echo "  Error output: $output"
        
        # Verify error message is helpful
        if echo "$output" | grep -qiE "(not found|error|failed)"; then
            echo "  PASS: Error message provides feedback"
        fi
        return 0
    else
        echo "WARN: Command succeeded unexpectedly - device may be present"
        echo "  Output: $output"
        return 1
    fi
}
```

## tdtool Return Codes Reference

From `telldus-core/client/telldus-core.h` and `telldus-core/tdtool/main.cpp`:

| Constant | Value | Meaning | Exit Code |
|----------|-------|---------|-----------|
| TELLSTICK_SUCCESS | 0 | Command succeeded | 0 |
| TELLSTICK_ERROR_NOT_FOUND | -1 | Generic not found error | 1 |
| TELLSTICK_ERROR_PERMISSION_DENIED | -2 | Permission denied | 2 |
| TELLSTICK_ERROR_DEVICE_NOT_FOUND | -3 | Device ID not in config | 3 |
| TELLSTICK_ERROR_METHOD_NOT_SUPPORTED | -4 | Device doesn't support method | 4 |
| TELLSTICK_ERROR_COMMUNICATION | -5 | Communication error | 5 |
| TELLSTICK_ERROR_CONNECTING_SERVICE | -6 | Cannot connect to telldusd | 6 |
| TELLSTICK_ERROR_UNKNOWN_RESPONSE | -7 | Unknown response from service | 7 |
| TELLSTICK_ERROR_SYNTAX | -8 | Command syntax error | 8 |
| TELLSTICK_ERROR_BROKEN_PIPE | -9 | Broken pipe during send | 9 |
| TELLSTICK_ERROR_COMMUNICATING_SERVICE | -10 | Service communication failed | 10 |
| TELLSTICK_ERROR_CONFIG_SYNTAX | -11 | Config file syntax error | 11 |
| TELLSTICK_ERROR_UNKNOWN | -99 | Unknown error | 99 |

**Note:** tdtool returns `-returnSuccess` (negated error code). Success (0) stays 0, errors become positive exit codes.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Native tdtool execution | `docker exec` pattern | Phase 6 (2026-05-15) | Cleaner container-native approach; no host/container socket path coordination |
| `--device /dev/ttyUSB0` | `--privileged` + libftdi VID/PID | Phase 6 (2026-05-15) | Handles device path changes transparently; simpler v1 deployment |
| Manual verification only | Executable script + manual checklist | Phase 7 (current) | Automated validation for CI; manual steps for hardware-specific checks |
| Full device testing (all devices) | Single representative device | Phase 7 context | Reduces RF traffic; faster verification; sufficient for proving functionality |

**Deprecated/outdated:**
- Testing all configured devices: Deferred to v1.x; single device is sufficient for v1
- Socket bind-mount for host tdtool: Deferred to v2 per D-06-06
- Native Arch verification: Explicitly out of scope per D-07-03, D-07-05

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | libftdi opens TellStick by VID/PID (0x1781/0x0C31), not device path | USB Detection | If wrong, device path changes between reboots would break connectivity; mitigated by `--privileged` granting all USB access |
| A2 | tdtool exit code 0 means command transmitted successfully | Command Verification | If wrong, verification may pass when command failed; code review confirms return logic in main.cpp line 622 |
| A3 | TellStick Duo VID/PID is 0x1781/0x0C31 | USB Detection | Verified by `lsusb` output: "ID 1781:0c31 Multiple Vendors Telldus TellStick Duo" |
| A4 | `docker exec` works as primary tdtool access pattern | Architecture | Verified in Phase 6; depends on container running and Unix sockets within container namespace |
| A5 | One-way 433 MHz communication means no device acknowledgment | Don't Hand-Roll | If wrong, there might be a way to verify device state; but 433 MHz protocols in codebase show one-way transmission |

## Open Questions

1. **Which device ID should be tested?**
   - What we know: First device in config is simplest; random selection spreads RF traffic; parameterized allows operator choice
   - What's unclear: Does the user's tellstick.conf have working devices that can be safely tested?
   - Recommendation: Default to first device, allow override via environment variable or command-line argument

2. **How to handle verification without physical TellStick?**
   - What we know: Error path verification is still valuable; tests can verify "fails correctly"
   - What's unclear: Should the script detect absence of hardware and skip vs fail?
   - Recommendation: Script detects USB presence; if absent, runs error-path tests only; if present, runs full verification

3. **Should verification include daemon logs inspection?**
   - What we know: Logs show USB connection events, command execution
   - What's unclear: Is log parsing reliable enough for automated verification?
   - Recommendation: Include optional log tail in verbose mode; primary verification uses tdtool exit codes

4. **What pause between ON and OFF commands?**
   - What we know: RF transmission takes time; devices need time to respond
   - What's unclear: How long is sufficient for all device types?
   - Recommendation: 1-2 second delay between commands; document that operator can adjust based on device

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker Engine | Container runtime | ✓ | 24.x+ | — |
| lsusb (usbutils) | USB device detection | ✓ | 2.14+ | — |
| TellStick Duo hardware | Full verification | ✓ | Firmware unknown | Error-path testing only |
| bash | Verification script | ✓ | 5.2+ | POSIX sh subset |
| grep | Pattern matching | ✓ | POSIX | — |
| docker exec | Container communication | ✓ | 24.x+ | — |

**Missing dependencies with no fallback:**
- None — all required tools are available

**Missing dependencies with fallback:**
- If TellStick Duo not connected: Script falls back to error-path verification (verifies graceful failure)

## Validation Architecture

> Skip this section if workflow.nyquist_validation is explicitly set to false. Absent = enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Shell script (bash) + Docker CLI |
| Config file | None — standalone script |
| Quick run command | `./scripts/verify-tellstick-hardware.sh` |
| Full suite command | `./scripts/verify-tellstick-hardware.sh --full` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DUO-01 | USB detection | integration | `verify_usb_detection` function in verify script | ❌ Wave 0 (create script) |
| DUO-03 | Device listing | integration | `verify_device_listing` function | ❌ Wave 0 |
| DUO-04 | On/off commands | integration | `verify_on_off_command` function | ❌ Wave 0 |
| DOCS-04 | Manual checklist | manual | `docs/verification-checklist.md` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Run verification script against running container
- **Per wave merge:** Full verification including manual checklist review
- **Phase gate:** Script runs successfully with TellStick connected

### Wave 0 Gaps
- [ ] `scripts/verify-tellstick-hardware.sh` — main verification script
- [ ] `docs/verification-checklist.md` — operator-facing checklist
- [ ] Integration with existing `scripts/test-container-runtime.sh`

## Security Domain

> Required when `security_enforcement` is enabled (absent = enabled). Omit only if explicitly `false`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A — local service, no auth |
| V3 Session Management | No | N/A — local IPC only |
| V4 Access Control | Yes | Container runs as root (deferred to v2); `--privileged` grants broad USB access |
| V5 Input Validation | Yes | Device ID validation in tdtool (atoi + bounds check) |
| V6 Cryptography | No | N/A — no crypto in this phase |

### Known Threat Patterns for Containerized USB

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| USB device escape via `--privileged` | Elevation of Privilege | Acceptable for v1 per D-06-01; document `--device` alternative for v2 |
| Container breakout via USB access | Elevation of Privilege | `--privileged` grants full device access; single-use/home deployment model mitigates |
| Host USB device disruption | Denial of Service | Container has full USB access; operator trust model |

**Key security note:** The verification script itself is low-risk (read-only observation, test commands), but documents the container's `--privileged` requirement. Security hardening (dedicated user, `--device` with udev rules) is explicitly deferred to v2 per Phase 6 decisions.

## Sources

### Primary (HIGH confidence)
- `telldus-core/client/telldus-core.h` - Error code constants (lines 128-140)
- `telldus-core/tdtool/main.cpp` - Exit code logic (line 622), command implementations
- `telldus-core/service/TellStick_libftdi.cpp` - USB VID/PID detection (lines 68, 251-259), libftdi usage
- `telldus-core/service/ControllerManager.cpp` - Controller detection (lines 85-136)
- `Dockerfile` - Container configuration, runtime libraries
- `scripts/docker-entrypoint.sh` - Container entrypoint behavior
- `scripts/test-container-runtime.sh` - Existing verification patterns
- `.planning/phases/06-containerized-daemon-runtime/06-CONTEXT.md` - USB passthrough decisions
- `.planning/phases/07-tellstick-duo-hardware-verification/07-CONTEXT.md` - Phase decisions and scope

### Secondary (MEDIUM confidence)
- Docker documentation: Runtime privilege and Linux capabilities - `--privileged` vs `--device` tradeoffs
- Docker documentation: Bind mounts - Config mounting patterns
- `.planning/codebase/ARCHITECTURE.md` - Service/client architecture
- `.planning/codebase/INTEGRATIONS.md` - Hardware integration boundaries

### Tertiary (LOW confidence)
- None — all claims verified against primary sources or codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All components proven in Phases 1-6
- Architecture: HIGH - Pattern established in Phase 6, documented in CONTEXT.md
- Pitfalls: MEDIUM-HIGH - Based on codebase analysis and 433 MHz protocol knowledge
- USB detection: HIGH - Verified with `lsusb` showing 1781:0c31 device
- Return codes: HIGH - Direct from telldus-core.h and tdtool/main.cpp source

**Research date:** 2026-05-15
**Valid until:** 30 days (stable domain: Docker, libftdi, shell scripting)

---

*Research complete. Planner can now create PLAN.md files for Phase 7.*
