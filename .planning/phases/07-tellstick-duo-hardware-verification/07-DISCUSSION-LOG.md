# Phase 07: TellStick Duo Hardware Verification - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 07-TellStick Duo Hardware Verification
**Areas discussed:** Verification scope, Native vs Docker priority, Device command verification

---

## Verification Scope

### Question 1: What minimum viable verification proves the TellStick Duo works for v1?

| Option | Description | Selected |
|--------|-------------|----------|
| Daemon detects USB device | telldusd starts and recognizes the TellStick Duo via libftdi | |
| tdtool lists configured devices | User's existing tellstick.conf loads and tdtool --list shows all devices | ✓ |
| Command transmission succeeds | tdtool --on/--off/--dim returns success | |
| Full cycle with real devices | Commands actually control real 433 MHz devices | |

**User's choice:** tdtool lists configured devices
**Notes:** This validates the full stack from config file → daemon → device enumeration.

---

### Question 2: Beyond the minimum, what additional verification belongs in Phase 7 v1?

| Option | Description | Selected |
|--------|-------------|----------|
| Command transmission test | Verify tdtool --on/--off/--dim returns success | ✓ |
| Sensor/receive path logging | Verify daemon logs raw receive events | |
| Docker verification equal to native | Verify identical behavior in Docker | |
| Stop at minimum | Phase 7 v1 ends at device listing | |

**User's choice:** Command transmission test
**Notes:** Adds command execution verification without requiring physical device responses.

---

### Question 3: How should command transmission be verified?

| Option | Description | Selected |
|--------|-------------|----------|
| tdtool return code only | tdtool --on returns exit code 0 (TELLSTICK_SUCCESS) | ✓ |
| Daemon log confirmation | Check daemon logs for send confirmation messages | |
| RF analyzer/sniffer | Use RTL-SDR to verify RF packets transmitted | |
| Loopback via TellStick receive | Transmit and receive same command | |

**User's choice:** tdtool return code only
**Notes:** Simplest verification, no special equipment needed.

---

### Question 4: What's the success criteria for Phase 7 complete?

| Option | Description | Selected |
|--------|-------------|----------|
| Native Arch verification only | Docker verification is bonus | |
| Both native and Docker | Must verify on both | |
| Docker as primary target | Docker verification is sufficient | ✓ |

**User's choice:** Docker as primary target
**Notes:** Docker is the deployment reality; native is development convenience.

---

## Native vs Docker Priority

### Question 1: Where do you connect the physical TellStick Duo first for initial verification?

| Option | Description | Selected |
|--------|-------------|----------|
| Native Arch first | Connect to Arch development machine first | |
| Docker first | Start with Docker as primary target | ✓ |
| Raspberry Pi directly | Skip Arch, verify on Pi target | |

**User's choice:** Docker first
**Notes:** Docker is the primary target from the start.

---

### Question 2: If Docker verification succeeds, what's required for native Arch verification?

| Option | Description | Selected |
|--------|-------------|----------|
| Quick sanity check only | Verify tdtool --list works natively | |
| Full parallel verification | Run identical test suite on native Arch | |
| Skip native entirely | Docker is the supported path | ✓ |

**User's choice:** Skip native entirely
**Notes:** Native Arch verification explicitly not required for Phase 7.

---

### Question 3: What's the Docker verification workflow?

| Option | Description | Selected |
|--------|-------------|----------|
| Single container test | Start container, run tdtool, stop container | ✓ |
| Restart/resilience test | Verify survives stop/start, USB disconnect | |
| Long-running soak test | Leave running for hours/days | |

**User's choice:** Single container test
**Notes:** Simplest verification for v1 scope.

---

### Question 4: How do you run tdtool commands against the Docker container?

| Option | Description | Selected |
|--------|-------------|----------|
| docker exec from host | Use `docker exec telldus-container tdtool --list` | |
| Shell inside container | Interactive bash shell inside container | |
| Either/both acceptable | Both methods should work | ✓ |

**User's choice:** Either/both acceptable
**Notes:** Flexibility for operator preference.

---

## Device Command Verification

### Question 1: Which device commands must be verified in Phase 7?

| Option | Description | Selected |
|--------|-------------|----------|
| On/off only | TELLSTICK_TURNON and TELLSTICK_TURNOFF | ✓ |
| On/off + dimming | Include TELLSTICK_DIM with dimlevel | |
| All supported methods | Also verify TELLSTICK_BELL and TELLSTICK_LEARN | |

**User's choice:** On/off only
**Notes:** Basic operations sufficient for v1 verification.

---

### Question 2: How do you select which device to test?

| Option | Description | Selected |
|--------|-------------|----------|
| Test all configured devices | Run on/off for every device | |
| Test one representative device | Pick one device from config | ✓ |
| Test by device ID parameter | Specify device ID via env var | |

**User's choice:** Test one representative device
**Notes:** Simpler, less RF noise, assumes protocol consistency.

---

### Question 3: What's the verification procedure?

| Option | Description | Selected |
|--------|-------------|----------|
| Turn on, verify success, turn off | Full cycle test | ✓ |
| Turn on only | Single command test | |
| Toggle current state | Read state, send opposite, verify | |

**User's choice:** Turn on, verify success, turn off
**Notes:** Full cycle confirms both directions work.

---

### Question 4: How do you handle verification without the TellStick Duo connected?

| Option | Description | Selected |
|--------|-------------|----------|
| Skip Phase 7 until hardware available | Cannot complete without hardware | |
| Create mock verification checklist | Write procedure without executing | |
| Use error cases as verification | Verify error paths when no hardware | ✓ |

**User's choice:** Use error cases as verification
**Notes:** Tests error paths (TELLSTICK_ERROR_NOT_FOUND) when hardware unavailable.

---

## Agent's Discretion

The user granted discretion in these areas:
- Structure of verification (manual checklist, shell script, or combination)
- Selection of specific device ID to test
- Optional diagnostic logging or debug output

## Deferred Ideas

Ideas noted for future phases:
- Sensor/receive path verification (deferred to v1.x or v2)
- Dimming command verification (deferred to v1.x)
- Bell and learn commands (deferred to v1.x)
- Long-running soak tests (production hardening for v2)
- RF packet analysis with RTL-SDR (advanced verification for v2)
- Explicit Raspberry Pi hardware verification (implied by Docker arm64 success)
