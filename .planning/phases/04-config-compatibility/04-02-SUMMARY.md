---
phase: 04-config-compatibility
plan: 02
subsystem: config
 tags: [inotify, libconfuse, config-reload, integration-test]

# Dependency graph
requires:
  - phase: 04-01
    provides: "Env var path overrides and state directory auto-creation"
provides:
  - Realistic multi-device sample tellstick.conf
  - Debounced inotify-based config auto-reload
  - Integration smoke test validating parse + reload
  - DeviceManager::reloadDevices for hot-reload without restart
affects:
  - 04-03
  - 05-01
  - 05-02

# Tech tracking
tech-stack:
  added: [inotify]
  patterns: [compile-time-default + runtime-override, debounced file watching]

key-files:
  created:
    - telldus-core/tests/integration/sample-tellstick.conf
    - telldus-core/tests/integration/config-compat-smoke.sh
    - telldus-core/tests/integration/config-compat-smoke.log
  modified:
    - telldus-core/service/Settings.h
    - telldus-core/service/SettingsConfuse.cpp
    - telldus-core/service/DeviceManager.h
    - telldus-core/service/DeviceManager.cpp
    - telldus-core/service/TelldusMain.cpp

key-decisions:
  - "Watch config parent directory with IN_CLOSE_WRITE | IN_MOVED_TO to catch both edits and atomic replacements"
  - "Debounce with 1-second sleep in watcher thread to avoid reload races during writes"
  - "Inline fillDevices logic in reloadDevices to avoid double-locking device list mutex"
  - "Guard all inotify code with #ifdef _LINUX; build succeeds on non-Linux"

patterns-established:
  - "ConfigWatcher thread class: inotify_init1 + non-blocking read loop + event signal to main EventHandler"
  - "reloadDevices pattern: clear old devices under lock, reload config, repopulate under same lock"

requirements-completed:
  - CONF-01
  - CONF-04

# Metrics
duration: 33min
completed: 2026-05-15
---

# Phase 04 Plan 02: Config Compatibility Validation Summary

**Debounced inotify-based config auto-reload integrated into telldusd event loop, with integration smoke test proving existing tellstick.conf parses correctly and detects external edits.**

## Performance

- **Duration:** 33 min
- **Started:** 2026-05-15T06:37:00Z
- **Completed:** 2026-05-15T07:10:00Z
- **Tasks:** 4
- **Files modified:** 8

## Accomplishments
- Realistic multi-device sample config with arctech and nexa protocols
- ConfigWatcher thread using inotify to watch parent directory for changes
- Debounce mechanism (1s sleep) prevents reload races during writes
- Settings::reloadConfig() re-parses stable config without touching var config
- DeviceManager::reloadDevices() clears, reloads, and repopulates device map atomically
- Integration smoke test validates parse, path overrides, and auto-reload end-to-end

## Task Commits

Each task was committed atomically:

1. **Task 1: Create realistic sample tellstick.conf** - `60f2bb7` (feat)
2. **Task 2: Add config auto-reload to daemon event loop** - `7a0b160` (feat)
3. **Task 3: Create integration smoke test script** - `3e7aec1` (feat)
4. **Task 4: Run smoke test and fix deadlock** - `7b6bddc` (fix)

**Plan metadata:** pending (this SUMMARY)

_Note: Task 4 discovered and fixed a deadlock in reloadDevices caused by double-locking the device list mutex._

## Files Created/Modified
- `telldus-core/tests/integration/sample-tellstick.conf` - Realistic multi-device config for validation
- `telldus-core/tests/integration/config-compat-smoke.sh` - Automated smoke test script
- `telldus-core/tests/integration/config-compat-smoke.log` - Test execution log showing PASS
- `telldus-core/service/Settings.h` - Added reloadConfig() declaration
- `telldus-core/service/SettingsConfuse.cpp` - Added reloadConfig() implementation
- `telldus-core/service/DeviceManager.h` - Added reloadDevices() declaration
- `telldus-core/service/DeviceManager.cpp` - Added reloadDevices() implementation (deadlock-safe)
- `telldus-core/service/TelldusMain.cpp` - Added ConfigWatcher thread and event loop integration

## Decisions Made
- Watch parent directory instead of file to catch atomic replacements (mv/overwrites)
- Debounce in watcher thread (sleep 1s + drain buffer) rather than using a timer in the event loop
- Inline fillDevices logic in reloadDevices to avoid double-locking; acceptable duplication for correctness
- Use `#ifdef _LINUX` guard (consistent with codebase) rather than `#ifdef __linux__`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed deadlock in DeviceManager::reloadDevices**
- **Found during:** Task 4 (Smoke test execution)
- **Issue:** reloadDevices() acquired d->lock via MutexLocker, then called fillDevices() which also acquired d->lock, causing a deadlock on the non-recursive mutex
- **Fix:** Inlined the fillDevices logic directly into reloadDevices() so the lock is held once across clear + reload + repopulate
- **Files modified:** telldus-core/service/DeviceManager.cpp
- **Verification:** Smoke test passes - daemon reloads config and tdtool lists all 4 devices
- **Committed in:** 7b6bddc (Task 4 commit)

**2. [Rule 3 - Blocking] Fixed smoke test build directory path detection**
- **Found during:** Task 4 (Smoke test execution)
- **Issue:** Script assumed build directory was under telldus-core/, but actual build is at repo root
- **Fix:** Added flexible build directory detection that checks repo root first, then falls back to telldus-core/
- **Files modified:** telldus-core/tests/integration/config-compat-smoke.sh
- **Verification:** Script finds telldusd and tdtool binaries correctly
- **Committed in:** 7b6bddc (Task 4 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes essential for correctness. No scope creep.

## Issues Encountered
- None beyond the auto-fixed deadlock and path detection issues

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Config auto-reload is working and tested
- Smoke test can be reused for Docker validation in Phase 5
- Path override mechanism (TELLDUS_CONFIG_FILE, TELLDUS_STATE_DIR) already in place from 04-01

---
*Phase: 04-config-compatibility*
*Completed: 2026-05-15*
