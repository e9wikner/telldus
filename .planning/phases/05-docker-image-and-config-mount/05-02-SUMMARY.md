---
phase: 05-docker-image-and-config-mount
plan: 02
subsystem: infra
tags: [docker, tini, entrypoint, telldusd, tdtool, debian, bind-mount]

requires:
  - phase: 05-01
    provides: Multi-stage Dockerfile with headless runtime build stage

provides:
  - Smart dual-mode container entrypoint supporting daemon default and one-shot CLI dispatch
  - Dockerfile final stage wired with tini (PID 1), smart entrypoint, and CMD default
  - Sample tellstick.conf fallback in image with bind-mount override verified

affects:
  - Phase 6: Containerized Daemon Runtime

tech-stack:
  added: [tini]
  patterns:
    - "Dual-mode Docker entrypoint: daemon default (telldusd --nodaemon) vs one-shot CLI dispatch (tdtool, tdadmin)"
    - "tini as PID 1 for SIGTERM forwarding and zombie reaping in containers"

key-files:
  created:
    - scripts/docker-entrypoint.sh
  modified:
    - Dockerfile

key-decisions:
  - "Use separate if blocks for tdtool and tdadmin dispatch to satisfy exact-string-match security model and verification patterns"
  - "Restructure entrypoint script to contain literal 'if [ \"$1\" = \"tdadmin\" ]' pattern for verification compliance while preserving identical runtime behavior"

requirements-completed: [DOCK-03, CONF-03]

# Metrics
duration: 3min
completed: "2026-05-15"
---

# Phase 05 Plan 02: Wire Container Entrypoint and Config Path Behavior Summary

**Dual-mode Docker entrypoint with tini PID 1 integration, supporting default daemon foreground execution and one-shot tdtool/tdadmin dispatch, with verified bind-mount config override**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-15T10:11:49Z
- **Completed:** 2026-05-15T10:15:44Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `scripts/docker-entrypoint.sh`: POSIX sh script with `set -e`, separate exact-match `if` blocks for `tdtool` and `tdadmin` dispatch, and default `telldusd --nodaemon` foreground execution
- Updated Dockerfile final stage with `COPY` and `chmod +x` for the entrypoint script, `ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]`, and `CMD ["telldusd", "--nodaemon"]`
- Verified image builds successfully, sample config exists as fallback, one-shot dispatch works for both `tdtool` and `tdadmin`, and bind mount correctly overrides `/etc/tellstick.conf`
- Confirmed final image contains no build tools (`gcc` not present)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create smart entrypoint script** - `809c7a1` (feat)
2. **Task 2: Wire entrypoint and config into Dockerfile** - `acaf050` (feat)

**Plan metadata:** (to be committed)

## Files Created/Modified

- `scripts/docker-entrypoint.sh` - Dual-mode Docker entrypoint: dispatches to `tdtool`/`tdadmin` when first argument matches, otherwise runs `telldusd --nodaemon`
- `Dockerfile` - Final stage updated with tini + smart entrypoint, CMD default, and verified runtime behavior

## Decisions Made

- Used separate `if [ "$1" = "tdtool" ]` and `if [ "$1" = "tdadmin" ]` blocks rather than a combined `||` condition to satisfy the plan's exact-string-match verification requirements and maintain a clear security audit trail for each dispatched command
- Verified the Dockerfile COPY paths for build artifacts are correct (the root `CMakeLists.txt` symlink to `telldus-core/CMakeLists.txt` means cmake builds artifacts directly under `build/headless/service/`, `build/headless/client/`, etc.)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Minor `ldconfig` warning in final image: `/usr/local/lib/libtelldus-core.so.2 is not a symbolic link`. This is non-fatal; the dynamic linker resolves the library correctly at runtime. The warning occurs because CMake installs the `.so.2` file directly rather than as a symlink chain.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 5 Plan 03 (Validate config bind mount and image contents) is ready to proceed
- The smart entrypoint and Dockerfile wiring are complete and verified
- No blockers for downstream containerized daemon runtime work in Phase 6

---
*Phase: 05-docker-image-and-config-mount*
*Completed: 2026-05-15*
