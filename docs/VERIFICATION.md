# Telldus Container Manual Verification Checklist

This document provides a step-by-step manual testing checklist for verifying container restart behavior and runtime persistence. Use this checklist when setting up Telldus for the first time or after infrastructure changes.

## Prerequisites

Before starting verification, ensure:

- [ ] Docker is installed and running (`docker --version`)
- [ ] Telldus Docker image is built (`docker images | grep telldus`)
- [ ] `tellstick.conf` configuration file exists on host
- [ ] TellStick Duo hardware is connected (for full verification)

## Test Environment Setup

```bash
# Set your config path
export TELLSTICK_CONFIG="/path/to/your/tellstick.conf"

# Verify config file exists
ls -la "$TELLSTICK_CONFIG"
```

---

## Test 1: Container Start

**Purpose:** Verify container starts successfully and daemon becomes ready.

**Command:**
```bash
docker run -d \
  --name telldus \
  --privileged \
  --restart unless-stopped \
  -v "$TELLSTICK_CONFIG":/etc/tellstick.conf:ro \
  -v telldus-state:/var/lib/telldus \
  telldus:latest
```

**Expected Results:**
- [ ] Container shows as "Up" in `docker ps`
- [ ] No immediate exit (check `docker ps` after 5 seconds)
- [ ] Logs show "telldusd daemon starting up"

**Verification:**
```bash
# Check container status
docker ps | grep telldus

# Expected output:
# CONTAINER ID   IMAGE           COMMAND                  CREATED          STATUS          PORTS     NAMES
# a1b2c3d4e5f6   telldus:latest  "/usr/bin/tini -- /u..." 10 seconds ago   Up 9 seconds              telldus

# Check logs for startup
docker logs telldus --tail 20

# Expected: "telldusd daemon starting up"
```

**Status:** ☐ PASS ☐ FAIL ☐ SKIP

---

## Test 2: tdtool Communication

**Purpose:** Verify tdtool can communicate with daemon via docker exec.

**Command:**
```bash
docker exec telldus tdtool --list
```

**Expected Results:**
- [ ] Command returns without error
- [ ] Device list is displayed (may be empty if no devices configured)
- [ ] No "Could not connect to the Telldus Service" error

**Sample Output:**
```
Number of devices: 3
1	Livingroom	dimmer	off
2	Kitchen		onoff		on
3	Porch		onoff		off
```

**Status:** ☐ PASS ☐ FAIL ☐ SKIP

---

## Test 3: Graceful Shutdown

**Purpose:** Verify container stops gracefully within timeout.

**Command:**
```bash
time docker stop telldus
```

**Expected Results:**
- [ ] Command completes in less than 2 seconds
- [ ] No hang or 10-second delay
- [ ] Container status shows "Exited (0)"

**Sample Output:**
```
real    0m0.8s
user    0m0.0s
sys     0m0.1s
```

**Status:** ☐ PASS ☐ FAIL ☐ SKIP

---

## Test 4: Restart and Persistence

**Purpose:** Verify container restarts and device list persists.

**Commands:**
```bash
# Capture device list before restart
BEFORE=$(docker exec telldus tdtool --list)
echo "Before restart:"
echo "$BEFORE"

# Restart container
docker restart telldus

# Wait for daemon ready
sleep 3

# Capture device list after restart
AFTER=$(docker exec telldus tdtool --list)
echo "After restart:"
echo "$AFTER"

# Compare
if [ "$BEFORE" = "$AFTER" ]; then
    echo "✓ Device lists match - persistence verified"
else
    echo "! Device lists differ (may be normal if devices changed state)"
fi
```

**Expected Results:**
- [ ] Container restarts successfully
- [ ] tdtool --list works after restart
- [ ] Device list matches (or differs only by device state changes)

**Status:** ☐ PASS ☐ FAIL ☐ SKIP

---

## Test 5: State Persistence

**Purpose:** Verify state directory exists and contains state file.

**Command:**
```bash
docker exec telldus ls -la /var/lib/telldus/
```

**Expected Results:**
- [ ] Directory `/var/lib/telldus` exists
- [ ] File `telldus-core.conf` exists (after devices have been controlled)
- [ ] Files have appropriate permissions (readable/writable by daemon)

**Sample Output:**
```
total 12
drwxr-xr-x 2 root root 4096 May 15 11:30 .
drwxr-xr-x 1 root root 4096 May 15 11:30 ..
-rw-r--r-- 1 root root  245 May 15 11:35 telldus-core.conf
```

**Note:** If `telldus-core.conf` does not exist, control a device first:
```bash
docker exec telldus tdtool --on 1
docker exec telldus tdtool --off 1
```

**Status:** ☐ PASS ☐ FAIL ☐ SKIP

---

## Test 6: Config Auto-Reload (Optional)

**Purpose:** Verify config changes apply without container restart.

**Prerequisites:** Understanding of tellstick.conf syntax

**Commands:**
```bash
# Note current device count
docker exec telldus tdtool --list | head -1

# Add a test device to config (edit on host)
# Then save the file

# Wait 2 seconds for inotify debounce
sleep 2

# Check if new device appears
docker exec telldus tdtool --list | head -1
```

**Expected Results:**
- [ ] Device count increases after config edit
- [ ] No container restart required
- [ ] Log shows configuration reload message

**Verification:**
```bash
# Check logs for reload message
docker logs telldus --tail 20 | grep -i reload
```

**Status:** ☐ PASS ☐ FAIL ☐ SKIP

---

## Test 7: USB Disconnect Recovery (Hardware Required)

**Purpose:** Verify container survives USB disconnection.

**Prerequisites:** TellStick Duo physically connected

**Commands:**
```bash
# Verify TellStick is detected
docker exec telldus lsusb | grep -i ftdi

# Physically disconnect TellStick
# Wait 5 seconds
# Physically reconnect TellStick
# Wait 5 seconds

# Verify TellStick is detected again
docker exec telldus lsusb | grep -i ftdi

# Verify daemon still running
docker ps | grep telldus

# Test device control
docker exec telldus tdtool --on 1
```

**Expected Results:**
- [ ] TellStick appears in lsusb after reconnect
- [ ] Container still running (no restart needed)
- [ ] Device commands work after reconnect
- [ ] Logs may show "Broken pipe" warnings but daemon continues

**Status:** ☐ PASS ☐ FAIL ☐ SKIP (hardware not available)

---

## Test 8: Restart Policy Verification

**Purpose:** Verify restart policy is correctly configured.

**Command:**
```bash
docker inspect telldus --format='{{.HostConfig.RestartPolicy.Name}}'
```

**Expected Results:**
- [ ] Output shows: `unless-stopped`

**Status:** ☐ PASS ☐ FAIL ☐ SKIP

---

## Automated Test Script

Run the automated test script for additional verification:

```bash
./scripts/test-container-runtime.sh
```

**Expected Results:**
- [ ] All 6 tests pass (or show WARN for hardware-related tests)
- [ ] No FAIL results

**Status:** ☐ PASS ☐ FAIL ☐ SKIP

---

## Sign-Off

I have completed the manual verification checklist and confirm:

**Tester:** _________________________ **Date:** ___________

**Environment:**
- Host OS: _________________________
- Docker version: _________________________
- TellStick Duo: ☐ Connected ☐ Not Available

**Results Summary:**
| Test | Status | Notes |
|------|--------|-------|
| 1. Container Start | ☐ PASS ☐ FAIL ☐ SKIP | |
| 2. tdtool Communication | ☐ PASS ☐ FAIL ☐ SKIP | |
| 3. Graceful Shutdown | ☐ PASS ☐ FAIL ☐ SKIP | |
| 4. Restart & Persistence | ☐ PASS ☐ FAIL ☐ SKIP | |
| 5. State Persistence | ☐ PASS ☐ FAIL ☐ SKIP | |
| 6. Config Auto-Reload | ☐ PASS ☐ FAIL ☐ SKIP | |
| 7. USB Disconnect Recovery | ☐ PASS ☐ FAIL ☐ SKIP | |
| 8. Restart Policy | ☐ PASS ☐ FAIL ☐ SKIP | |
| Automated Script | ☐ PASS ☐ FAIL ☐ SKIP | |

**Overall Status:** ☐ ALL TESTS PASSED ☐ SOME TESTS FAILED ☐ INCOMPLETE

**Notes/Issues:**
______________________________________________________________________________
______________________________________________________________________________
______________________________________________________________________________

---

## Troubleshooting Quick Reference

| Issue | Diagnostic Command | Solution |
|-------|-------------------|----------|
| Container won't start | `docker logs telldus` | Check config file path and syntax |
| tdtool connection failed | `docker ps && docker logs telldus` | Wait for daemon startup, check logs |
| TellStick not detected | `docker exec telldus lsusb` | Verify `--privileged` flag |
| State lost after restart | `docker inspect telldus` | Add `-v telldus-state:/var/lib/telldus` |
| Shutdown takes 10s | `docker inspect telldus --format='{{.Config.Entrypoint}}'` | Verify tini is ENTRYPOINT |

---

## References

- [Docker Runtime Guide](./docker-runtime.md) - Full runtime documentation
- [06-RESEARCH.md](../.planning/phases/06-containerized-daemon-runtime/06-RESEARCH.md) - Phase 6 research notes
- [06-CONTEXT.md](../.planning/phases/06-containerized-daemon-runtime/06-CONTEXT.md) - Implementation decisions (D-06-10 through D-06-13)
