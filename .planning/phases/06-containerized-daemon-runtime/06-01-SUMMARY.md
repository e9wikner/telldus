---
phase: 06-containerized-daemon-runtime
plan: 06-01
subsystem: infra
tags: [docker, docker-compose, usb-passthrough, deployment]

requires:
  - phase: 05-docker-image-and-config-mount
    provides: Dockerfile with tini entrypoint and telldus:latest image

provides:
  - docker-compose.yml for production deployment with USB passthrough
  - scripts/run-telldus.sh helper script for docker run commands
  - Configuration for --privileged USB access
  - State persistence via named volumes
  - Restart policy for auto-recovery

affects:
  - 06-02-tdtool-docker-exec-interface
  - 06-03-signal-handling-and-shutdown

tech-stack:
  added: [docker-compose]
  patterns:
    - "Privileged container mode for USB device passthrough"
    - "Named Docker volumes for state persistence"
    - "unless-stopped restart policy for resilience"

key-files:
  created:
    - docker-compose.yml
    - scripts/run-telldus.sh
  modified: []

key-decisions:
  - "D-06-01: Use --privileged for USB passthrough (v1 pragmatic choice)"
  - "D-06-10: Use restart: unless-stopped policy for auto-recovery"
  - "D-06-12: State persistence via named volume for /var/lib/telldus"

requirements-completed: [DOCK-02, DUO-02]

duration: 2min
completed: 2026-05-15
---

# Phase 06 Plan 01: Docker Run Options for USB Passthrough and Service Permissions

**Deployment artifacts with --privileged USB passthrough, state volume persistence, and auto-restart policy for TellStick Duo operation in Docker**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-15T11:22:11Z
- **Completed:** 2026-05-15T11:24:34Z
- **Tasks:** 3
- **Files created:** 2

## Accomplishments

- Created docker-compose.yml with complete TellStick Duo deployment configuration
- Created scripts/run-telldus.sh executable helper script for one-command deployment
- Documented all design decisions (D-06-01, D-06-10, D-06-12) in file comments
- Configured --privileged mode for reliable USB device access
- Implemented named volume persistence for runtime state across container restarts
- Added restart: unless-stopped for automatic recovery from crashes and host reboots

## Task Commits

Each task was committed atomically:

1. **Task 1: Create docker-compose.yml** - `9a56b98e` (feat)
2. **Task 2: Create scripts/run-telldus.sh** - `2e02730c` (feat)
3. **Task 3: Add docker-compose usage documentation** - `3d1288a8` (docs)

**Plan metadata:** (part of Task 3 commit)

## Files Created

- `docker-compose.yml` - Docker Compose configuration for production deployment
  - Service: telldus with privileged: true for USB access
  - Restart policy: unless-stopped for auto-recovery
  - Named volume: telldus-state for /var/lib/telldus persistence
  - Config bind mount: read-only /etc/tellstick.conf from host
  - Optional resource limits: 64M memory, 0.25 CPU

- `scripts/run-telldus.sh` - Executable helper script for docker run
  - Configurable CONFIG_PATH for user-specific config location
  - All required flags: --privileged, --restart unless-stopped
  - State volume: telldus-state:/var/lib/telldus
  - Pre-flight config file existence check
  - Post-start verification commands and usage hints

## Decisions Made

All key decisions were documented per the research phase:

1. **D-06-01: --privileged for USB passthrough** - Implemented in both artifacts. The v1 pragmatic choice trades some isolation for reliability. Future versions may use fine-grained capabilities.

2. **D-06-10: restart: unless-stopped** - Provides automatic recovery from daemon crashes and host reboots, while respecting intentional stops via `docker-compose down`.

3. **D-06-12: Named volume for state persistence** - The `telldus-state` volume ensures device states and learned devices survive container recreation.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Verification Results

All plan verification commands passed:

```bash
# Structure verification
ls -la docker-compose.yml scripts/run-telldus.sh
# Result: Both files exist with correct permissions (-rw-r--r-- and -rwxr-xr-x)

# Configuration verification
grep -E 'privileged:|restart:|telldus-state:' docker-compose.yml
# Result: All three patterns found (privileged: true, restart: unless-stopped, telldus-state volume)

# Script verification
head -20 scripts/run-telldus.sh
# Result: Shows docker run command with all required flags
```

Acceptance criteria verification:
- ✓ docker-compose.yml contains privileged: true
- ✓ docker-compose.yml contains restart: unless-stopped
- ✓ docker-compose.yml contains config bind mount with :ro suffix
- ✓ docker-compose.yml contains telldus-state:/var/lib/telldus
- ✓ docker-compose.yml defines volumes section with driver: local
- ✓ scripts/run-telldus.sh exists and is executable
- ✓ scripts/run-telldus.sh contains --privileged flag
- ✓ scripts/run-telldus.sh contains --restart unless-stopped
- ✓ scripts/run-telldus.sh contains state volume mount
- ✓ scripts/run-telldus.sh contains config bind mount with :ro suffix

## Usage Examples

### Docker Compose (Recommended)

```bash
# Start daemon
docker-compose up -d

# List devices
docker-compose exec telldus tdtool --list

# View logs
docker-compose logs -f

# Stop daemon
docker-compose down
```

### Helper Script

```bash
# 1. Edit CONFIG_PATH in scripts/run-telldus.sh
# 2. Run
./scripts/run-telldus.sh

# 3. Verify
docker exec telldus tdtool --list
docker exec telldus lsusb | grep -i ftdi
```

### Direct Docker Run

```bash
docker run -d \
    --name telldus \
    --privileged \
    --restart unless-stopped \
    -v /path/to/tellstick.conf:/etc/tellstick.conf:ro \
    -v telldus-state:/var/lib/telldus \
    telldus:latest
```

## User Setup Required

None - no external service configuration required. However, operators must:

1. Build the Docker image from Phase 5: `docker build -t telldus:latest .`
2. Provide a valid tellstick.conf file on the host
3. Edit CONFIG_PATH in scripts/run-telldus.sh or docker-compose.yml to point to their config

## Next Phase Readiness

Ready for 06-02: tdtool Docker exec interface. The foundation for running telldusd in Docker with proper USB access and persistence is now complete.

---
*Phase: 06-containerized-daemon-runtime*
*Plan: 06-01*
*Completed: 2026-05-15*
