---
phase: 07-tellstick-duo-hardware-verification
plan: 07-03
wave: 3
completed: 2026-05-15
---

# Plan 07-03 Summary: Error Paths and Edge Cases

## Objective
Verify error handling and edge cases when TellStick Duo is not connected or invalid commands are issued. Per D-07-11, error path verification ensures graceful failure.

**Note:** Dimming (DUO-05) and sensor/receive (DUO-06) are OUT OF SCOPE per locked decisions D-07-08 and D-07-04.

## What Was Built

### 1. scripts/verify-error-paths.sh
Dedicated automated error path verification script:

**Functions:**
- **verify_no_hardware_error()**: Tests graceful failure without TellStick
  - Checks if USB is absent
  - Runs tdtool --list and verifies non-zero exit code
  - Validates error message is meaningful
  
- **verify_invalid_device_error()**: Tests invalid device ID handling
  - Uses device ID 999 (non-existent)
  - Verifies exit code 3 (TELLSTICK_ERROR_DEVICE_NOT_FOUND)
  - Validates proper error response

- **verify_daemon_connection_error()**: Tests connection failures
  - Attempts connection to non-existent container
  - Verifies graceful error handling

- **verify_malformed_command()**: Tests invalid argument handling
  - Uses invalid tdtool flag
  - Verifies appropriate error response

**Features:**
- Complete tdtool exit code reference table
- Color-coded output (PASS/FAIL/SKIP)
- Handles hardware-present case (skips no-hardware tests)
- Comprehensive test coverage for error scenarios

### 2. docs/hardware-verification.md (updated)
Added "Error Path Verification" section:

- **Error Scenarios**: No hardware, invalid device ID, daemon not running
- **Exit Code Reference**: Complete table of tdtool error codes 0-11 and 99
- **Automated Verification**: Reference to verify-error-paths.sh
- **CI Testing**: Documentation for --error-only mode

### 3. scripts/verify-tellstick-hardware.sh (enhanced)
Already implemented in Wave 2 with --error-only mode:

- **--error-only flag**: Runs only error path tests
- **verify_tdtool_without_daemon()**: Connection error test
- **verify_invalid_device_id()**: Invalid device ID test
- Suitable for CI environments without hardware

## Acceptance Criteria Verification

| Criteria | Status | Evidence |
|----------|--------|----------|
| Error script exists | ✓ | scripts/verify-error-paths.sh created |
| No hardware function | ✓ | verify_no_hardware_error() implemented |
| Invalid device function | ✓ | verify_invalid_device_error() implemented |
| Exit code 3 check | ✓ | TELLSTICK_ERROR_DEVICE_NOT_FOUND verification |
| Error-only mode | ✓ | --error-only flag in verify-tellstick-hardware.sh |
| Error code table | ✓ | Complete table 0-11, 99 in docs |
| Documentation | ✓ | Error Path Verification section added |
| CI testing docs | ✓ | CI testing without hardware documented |

## Key Decisions Honored

- **D-07-11**: Error path verification when hardware not connected
- **D-07-08**: Dimming out of scope (not tested)
- **D-07-04**: Sensors out of scope (not tested)
- **D-07-03**: Docker as primary target

## Testing

Scripts syntax verified:
```bash
bash -n scripts/verify-error-paths.sh  # Syntax OK
test -x scripts/verify-error-paths.sh  # Executable
grep -q "verify_no_hardware_error" scripts/verify-error-paths.sh
grep -q "verify_invalid_device_error" scripts/verify-error-paths.sh
```

## Output Artifacts

| File | Purpose |
|------|---------|
| scripts/verify-error-paths.sh | Dedicated error path verification |
| docs/hardware-verification.md | Error path documentation with exit code reference |
| scripts/verify-tellstick-hardware.sh | Enhanced with --error-only mode |

## Next Steps

Wave 4 (Plan 07-04) - Final deliverable:
- Comprehensive manual verification checklist
- Complete operator-facing documentation
- Final polish on all scripts and docs

## Requirements Addressed

- **D-07-11**: Error path verification - graceful failure without hardware
- **DUO-01**: Error handling for USB detection failures

## Out of Scope (Per Locked Decisions)

- **DUO-05**: Dimming commands - per D-07-08, deferred to v1.x
- **DUO-06**: Sensor/receive path - per D-07-04, deferred to v1.x or v2
