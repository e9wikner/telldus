---
phase: 05-docker-image-and-config-mount
plan: 01
subsystem: infra
tags: [docker, debian, multi-stage, cmake, tini, cppunit]

requires:
  - phase: 04-config-compatibility
    provides: Config path decisions and inotify watcher for bind-mount reload

provides:
  - Multi-stage Dockerfile with build and runtime stages
  - .dockerignore with 15 exclusion patterns
  - CMakePresets.json with BUILD_TDADMIN=TRUE

affects:
  - 05-02 (entrypoint refinement and smart dispatch)
  - 05-03 (config bind mount validation)

tech-stack:
  added: [docker multi-stage, tini]
  patterns: [deps-first layer caching, build-stage test gate]

key-files:
  created:
    - Dockerfile
    - .dockerignore
  modified:
    - CMakePresets.json

key-decisions:
  - "libconfuse2 (not libconfuse0) is the correct Debian bookworm runtime package name"

patterns-established:
  - "Build-stage test gate: ctest -R cppunit fails the build if tests fail"
  - "Deps-first layer caching: apt install before COPY . . so dependency layer is cacheable"

requirements-completed: [DOCK-01]

duration: 12min
completed: 2026-05-15
---

# Phase 05 Plan 01: Docker Image and Config Mount Summary

**Multi-stage Dockerfile builds headless Telldus Core runtime in Debian bookworm-slim with CppUnit test gate and minimal final stage containing only runtime libraries and production binaries.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-15T09:53:18Z
- **Completed:** 2026-05-15T10:06:01Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Created .dockerignore with 15 patterns keeping build context under ~54 kB
- Enabled BUILD_TDADMIN=TRUE in headless preset so tdadmin binary is produced
- Built multi-stage Dockerfile: build stage compiles and tests; final stage is ~200 MB with only runtime deps
- Verified `docker build --target build` and full image build both succeed
- Verified CppUnit tests pass inside the container (100% tests passed)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create .dockerignore** - `06af1d6` (chore)
2. **Task 2: Enable BUILD_TDADMIN in headless preset** - `050915b` (chore)
3. **Task 3: Create multi-stage Dockerfile** - `43eb2cf` (feat)

**Plan metadata:** (to be committed with SUMMARY.md)

## Files Created/Modified
- `.dockerignore` — 15 exclusion patterns for minimal Docker build context
- `CMakePresets.json` — Changed BUILD_TDADMIN from FALSE to TRUE in headless preset
- `Dockerfile` — Multi-stage build with debian:bookworm-slim, deps-first caching, CppUnit gate, runtime-only final stage

## Decisions Made
- Used `COPY . .` in build stage because the repo uses root-level symlinks (CMakeLists.txt -> telldus-core/CMakeLists.txt, common -> telldus-core/common, etc.) that must be preserved for cmake to resolve paths correctly
- Chose `libconfuse2` as the runtime package after discovering `libconfuse0` does not exist in Debian bookworm (deviation Rule 1)
- Kept placeholder ENTRYPOINT with tini and /bin/sh as interim (refined in 05-02)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed libconfuse runtime package name**
- **Found during:** Task 3 (Dockerfile final stage build)
- **Issue:** Plan and research specified `libconfuse0` for Debian bookworm runtime, but `apt-get install` failed with "Unable to locate package libconfuse0"
- **Fix:** Changed `libconfuse0` to `libconfuse2` in the final stage RUN instruction
- **Files modified:** Dockerfile
- **Verification:** `docker build -t telldus:latest .` succeeded after the fix
- **Committed in:** `43eb2cf` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary package name correction for Debian 12 compatibility. No scope creep.

## Issues Encountered
- Docker COPY --from=build with wildcard `libtelldus-core.so*` copies symlink targets as regular files, causing a harmless ldconfig warning about "not a symbolic link". All three library files exist and work correctly at runtime.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Dockerfile and build pipeline are ready for Plan 05-02 (entrypoint refinement with smart tdtool/telldusd dispatch)
- Build stage image (`telldus:build`) can be reused for rapid iteration
- No blockers for next plan

## Self-Check: PASSED

- [x] Dockerfile exists at repo root
- [x] docker build --target build -t telldus:build . exits 0
- [x] docker run --rm telldus:build ctest shows 100% tests passed
- [x] docker build -t telldus:latest . exits 0
- [x] Final image contains telldusd, tdtool, tdadmin, libtelldus-core, sample config
- [x] .dockerignore has >=8 patterns
- [x] CMakePresets.json has BUILD_TDADMIN: TRUE

---
*Phase: 05-docker-image-and-config-mount*
*Completed: 2026-05-15*
