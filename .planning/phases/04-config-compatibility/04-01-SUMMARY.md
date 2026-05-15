---
phase: 04-config-compatibility
plan: 01
type: execute
subsystem: config, service, build
tags: [cmake, linux-paths, environment-variables, state-directory, docker-ready]

requires:
  - phase: 03-raspberry-pi-portability
    provides: Working headless build on Debian aarch64 and Arch Linux

provides:
  - Linux default state directory updated from /var/state to /var/lib/telldus
  - Runtime env var overrides for config and state paths
  - Daemon startup auto-creation of state directory
  - Zero new compiler warnings

affects:
  - 04-02 (config validation against sample)
  - 04-03 (config/state separation across restarts)
  - 05-01 (Docker image build)
  - 05-02 (container entrypoint / config mount)

tech-stack:
  added: []
  patterns:
    - "Compile-time default + runtime getenv override for paths"
    - "Daemon startup directory creation with stat/mkdir"

key-files:
  created: []
  modified:
    - telldus-core/service/CMakeLists.txt - Default STATE_INSTALL_DIR changed to /var/lib/telldus
    - telldus-core/service/SettingsConfuse.cpp - Runtime env var path resolution helpers
    - telldus-core/service/main_unix.cpp - State directory auto-creation at startup

key-decisions:
  - "FreeBSD /var/spool path preserved untouched per D-04-13"
  - "Used std::string for path concatenation instead of std::filesystem to avoid C++17 dependency"
  - "State directory creation placed before privilege dropping so it runs as root"

requirements-completed:
  - CONF-01
  - CONF-02

completed: 2026-05-15
---

# Phase 04 Plan 01: Linux Config and State Path Modernization Summary

**Modernized Linux config/state paths with FHS-compliant /var/lib/telldus default, runtime env var overrides, and daemon startup directory auto-creation — zero new compiler warnings.**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-05-15T06:10:00Z (approximate)
- **Completed:** 2026-05-15T06:32:19Z
- **Tasks:** 4
- **Files modified:** 3

## Accomplishments

- Changed Linux default state install directory from deprecated `/var/state` to `/var/lib/telldus`
- Added `TELLDUS_CONFIG_FILE` and `TELLDUS_STATE_DIR` runtime environment variable overrides
- Implemented daemon startup auto-creation of state directory with `0755` permissions
- Verified build produces zero new warnings from modified files

## Task Commits

Each task was committed atomically:

1. **Task 1: Update default state install directory in CMakeLists.txt** - `6977438` (fix)
2. **Task 2: Add runtime path override via environment variables** - `00f2eae` (feat)
3. **Task 3: Auto-create state directory at daemon startup** - `65ba25d` (feat)
4. **Task 4: Build and verify zero new warnings** - `1f5f0bc` (fix)

**Plan metadata:** to-be-committed (docs: complete plan)

## Files Created/Modified

- `telldus-core/service/CMakeLists.txt` - Linux `DEFAULT_STATE_INSTALL_DIR` changed from `/var/state` to `/var/lib/telldus`; FreeBSD `/var/spool` preserved
- `telldus-core/service/SettingsConfuse.cpp` - Added `getConfigFilePath()` and `getVarConfigPath()` helpers that check `TELLDUS_CONFIG_FILE` and `TELLDUS_STATE_DIR` with compile-time fallbacks; all `fopen()` calls updated
- `telldus-core/service/main_unix.cpp` - Added state directory `stat()`/`mkdir()` sequence before privilege dropping; includes `service/config.h` for `VAR_CONFIG_PATH`

## Decisions Made

- FreeBSD path preserved exactly as specified in D-04-13 — only the Linux `ELSE()` branch was modified
- Used `std::string` for path concatenation instead of `std::filesystem` to avoid introducing a C++17 dependency into the existing C++98/03 codebase
- Placed directory creation before the root privilege-dropping block so it runs with sufficient permissions
- Did not auto-create `/etc` — the task explicitly stated this is the OS's responsibility

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing `#include "service/config.h"` in main_unix.cpp**
- **Found during:** Task 4 (Build verification)
- **Issue:** `VAR_CONFIG_PATH` was not declared in scope in `main_unix.cpp` because the CMake-generated `config.h` was not included
- **Fix:** Added `#include "service/config.h"` to resolve the compile-time constant
- **Files modified:** `telldus-core/service/main_unix.cpp`
- **Verification:** Build succeeded with `cmake --build build/headless --target telldusd`
- **Committed in:** `1f5f0bc` (Task 4 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor build fix. No scope creep. All planned functionality delivered.

## Issues Encountered

- `replaceAll` on `CONFIG_FILE` accidentally matched the substring inside the string literal `"TELLDUS_CONFIG_FILE"` and inside `VAR_CONFIG_FILE`, causing two transient corruptions that were caught and fixed during Task 2 before commit.
- Build log file `build/headless/04-01-build.log` was created but is in the `build/` directory which is `.gitignore`d; it was not committed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Config path modernization is complete and builds cleanly.
- Ready for **04-02**: Validate existing config loading against a user-provided sample.
- No blockers.

## Self-Check: PASSED

- All key files exist on disk: `telldus-core/service/CMakeLists.txt`, `SettingsConfuse.cpp`, `main_unix.cpp`, `04-01-SUMMARY.md`
- All task commits verified in git history: `6977438`, `00f2eae`, `65ba25d`, `1f5f0bc`
- Plan metadata commit verified: `58a34bd`
- State/ROADMAP/REQUIREMENTS metadata commit verified: `64ecf56`

---
*Phase: 04-config-compatibility*
*Completed: 2026-05-15*
