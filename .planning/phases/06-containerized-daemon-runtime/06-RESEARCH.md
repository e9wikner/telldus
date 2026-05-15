# Phase 06: Containerized Daemon Runtime - Research

**Researched:** 2026-05-15  
**Domain:** Docker container runtime, USB device passthrough, process management, IPC patterns  
**Confidence:** HIGH

## Summary

Phase 6 operationalizes the Docker image from Phase 5 by defining runtime patterns for USB passthrough, container lifecycle management, and `tdtool` communication. The implementation leverages Docker's `--privileged` mode for reliable USB access, uses `docker exec` as the primary tdtool interface, and establishes restart-safe behavior through volume persistence and signal handling.

**Primary recommendation:** Deploy with `docker run --privileged --name telldus -v /host/config:/etc/tellstick.conf -v telldus-state:/var/lib/telldus telldus:latest`, then use `docker exec telldus tdtool --list` for device operations. No host socket exposure required.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| USB device access | Container Runtime (Docker) | Host kernel | `--privileged` grants container USB subsystem access |
| Daemon process lifecycle | Container Runtime (tini + entrypoint) | — | tini as PID 1 handles signals, entrypoint dispatches |
| Client-daemon IPC | Container-internal Unix sockets | — | `/tmp/TelldusClient` and `/tmp/TelldusEvents` are container-local |
| tdtool CLI interface | Host operator via `docker exec` | — | No socket bind-mount needed; exec pattern is cleaner |
| Config persistence | Host filesystem (bind mount) | — | `/etc/tellstick.conf` mounted from host |
| State persistence | Docker volume or bind mount | — | `/var/lib/telldus` survives container restart |
| Signal handling | Daemon (SIGTERM/SIGINT handlers) | tini forwarding | main_unix.cpp handles graceful shutdown |
| USB disconnect recovery | libftdi internal retry logic | — | Daemon does not exit on USB errors (line 176 in TellStick_libftdi.cpp) |

## Standard Stack

### Core Runtime Components

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Docker Engine | 20.10+ | Container runtime | Industry standard, supports `--privileged` and USB passthrough |
| tini | 0.19+ | Init system for PID 1 | Proper signal forwarding, zombie reaping; already in image from Phase 5 |
| libftdi1 | 1.5+ | USB FTDI communication | Opens devices by VID/PID/serial, handles varying `/dev/ttyUSB*` paths |
| Unix domain sockets | — | Client-daemon IPC | Standard Linux IPC, container-local at `/tmp/Telldus{Client,Events}` |
| inotify | — | Config auto-reload | Phase 4 implementation watches `/etc/tellstick.conf` parent directory |

### Operational Patterns

| Pattern | Implementation | Use Case |
|---------|---------------|----------|
| `docker exec` | `docker exec <container> tdtool <args>` | Primary tdtool access pattern |
| Volume persistence | `-v telldus-state:/var/lib/telldus` | Runtime state survives restarts |
| Config bind mount | `-v /host/tellstick.conf:/etc/tellstick.conf` | User config injection |
| Restart policy | `--restart unless-stopped` | Auto-recovery from crashes/reboots |
| Privileged USB | `--privileged` | Reliable TellStick Duo access for v1 |

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Host System                               │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Docker Container                         │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌────────────────┐  │   │
│  │  │   tini      │───→│ entrypoint  │───→│ telldusd       │  │   │
│  │  │  (PID 1)    │    │  (dispatch) │    │  (--nodaemon)  │  │   │
│  │  └─────────────┘    └─────────────┘    └───────┬────────┘  │   │
│  │         │                                      │           │   │
│  │         │ Signal forwarding                    │           │   │
│  │         ↓                                      ↓           │   │
│  │  ┌─────────────┐                        ┌──────────────┐   │   │
│  │  │   SIGTERM   │←───────────────────────│ SignalHandler│   │   │
│  │  │   SIGINT    │                        │ (graceful    │   │   │
│  │  └─────────────┘                        │  shutdown)   │   │   │
│  │                                          └──────────────┘   │   │
│  │                                                      │      │   │
│  │                                          ┌───────────┴────┐ │   │
│  │                                          │ Unix Sockets   │ │   │
│  │                                          │/tmp/TelldusClient│  │   │
│  │                                          │/tmp/TelldusEvents│  │   │
│  │                                          └───────┬────────┘ │   │
│  │                                                  │          │   │
│  │  ┌───────────────────────────────────────────────┘          │   │
│  │  │                                                          │   │
│  │  │ docker exec                                              │   │
│  │  ↓                                                          │   │
│  │  ┌─────────────┐    ┌─────────────┐                        │   │
│  │  │   tdtool    │───→│   Client    │────────────────────────┘   │
│  │  │  (exec'd)   │    │  Library    │                            │
│  │  └─────────────┘    └─────────────┘                            │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────┐              ┌─────────────────────────────┐      │
│  │ tellstick.  │ (bind mount) │    /var/lib/telldus         │      │
│  │   conf      │─────────────→│   (volume/bind mount)       │      │
│  └─────────────┘              └─────────────────────────────┘      │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │           TellStick Duo (USB) ──→ libftdi1                  │   │
│  │              (via --privileged passthrough)                 │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Data Flow: tdtool Command Execution

```
Host shell: docker exec telldus tdtool --on 1
                    │
                    ↓
Docker creates ephemeral exec container
                    │
                    ↓
entrypoint.sh sees "$1" = "tdtool", execs tdtool
                    │
                    ↓
tdtool main() → tdInit() → Client connects to /tmp/TelldusClient
                    │
                    ↓
Unix socket IPC to daemon
                    │
                    ↓
Daemon processes command → libftdi1 → USB → TellStick Duo
```

### Recommended Project Structure

```
.
├── Dockerfile                              # Phase 5 deliverable
├── scripts/
│   ├── docker-entrypoint.sh               # Phase 5 deliverable
│   └── run-telldus.sh                     # NEW: Helper for docker run
├── docker-compose.yml                      # NEW: Production deployment
├── docs/
│   └── docker-runtime.md                  # NEW: Runtime documentation
└── .planning/phases/06-containerized-daemon-runtime/
    └── 06-RESEARCH.md                     # This file
```

### Pattern 1: Container Startup Sequence

**What:** Defined startup order from `docker run` through to daemon ready state

**When to use:** Every container start, including restart after crash or host reboot

**Sequence:**
1. Docker creates container with `--privileged` USB access
2. Bind mounts: `/etc/tellstick.conf` (config), `/var/lib/telldus` (state)
3. tini starts as PID 1
4. tini executes entrypoint.sh
5. entrypoint.sh: `$1` is "telldusd", so execs `telldusd --nodaemon`
6. telldusd creates `/tmp/TelldusClient` and `/tmp/TelldusEvents` sockets
7. libftdi1 scans USB, opens TellStick Duo by VID/PID/serial
8. Daemon enters event loop, ready for commands

### Pattern 2: Graceful Shutdown

**What:** Clean daemon termination on container stop

**When to use:** `docker stop`, `SIGTERM` to container, host shutdown

**Flow:**
1. Docker sends SIGTERM to container (PID 1, which is tini)
2. tini forwards SIGTERM to telldusd
3. `signalHandler(SIGTERM)` in main_unix.cpp logs and calls `tm.stop()`
4. `TelldusMain::stop()` signals event handler, stops threads
5. Controller threads exit, USB handles closed
6. Unix sockets unlinked
7. Log message: "telldusd daemon exited"
8. tini exits, container stops

**Timeout:** Docker default is 10s, then SIGKILL. The daemon shuts down in < 1s normally.

### Pattern 3: USB Disconnect/Reconnect Resilience

**What:** Container survives temporary USB disconnection

**When to use:** TellStick Duo unplugged/replugged, USB hub reset, power fluctuation

**Mechanism:**
- libftdi1's `ftdi_read_data()` returns errors on disconnect (TellStick_libftdi.cpp:172-177)
- Daemon sleeps 1s on error, retries continuously
- Daemon does NOT exit on USB errors (explicit design per D-06-11)
- When USB reconnects, libftdi1 auto-reopens on next operation
- Container keeps running, state preserved

**Warning signs:** Log messages "Broken pipe on read" indicate USB issues but daemon continues

### Pattern 4: Config Reload Without Restart

**What:** Configuration changes apply without container restart

**When to use:** User edits `/etc/tellstick.conf` on host

**Mechanism (from Phase 4):**
1. inotify watcher monitors parent directory of config file
2. `IN_CLOSE_WRITE` or `IN_MOVED_TO` events trigger reload
3. 1-second debounce prevents race conditions during writes
4. Device list reloaded, new devices available immediately
5. No container restart, no daemon restart, no state loss

### Anti-Patterns to Avoid

- **Binding Unix sockets to host:** Creating `/tmp/TelldusClient` on the host and bind-mounting into container. Adds complexity, path coordination issues, and offers no benefit over `docker exec`.

- **Running without --privileged:** Attempting fine-grained `--device` or `--cap-add` for v1. While possible, it's error-prone and adds troubleshooting friction. Deferred to v2 per D-06-02.

- **Expecting daemon to exit on USB failure:** The daemon is designed to retry indefinitely. Don't configure Docker to restart on USB errors.

- **Using `latest` tag in production scripts:** Always pin to specific version/tag for reproducibility.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Init system for containers | Custom signal handling script | tini (already in image) | Battle-tested PID 1, proper zombie reaping, SIGTERM forwarding |
| USB device discovery | Parsing `/dev/ttyUSB*` paths | libftdi1's `ftdi_usb_find_all()` | Handles varying paths, serial number matching, hotplug |
| Client-daemon IPC | Network sockets, D-Bus | Unix domain sockets (existing) | Zero overhead, container-local, no network exposure |
| Process supervision | docker-compose `restart: always` | `restart: unless-stopped` | Respects manual `docker stop`, prevents restart loops |
| Log aggregation | File-based logging inside container | stdout/stderr with `docker logs` | Docker-native, survives container loss, centralizes logs |

## Runtime State Inventory

> Phase 6 is operational/runtime focused — no rename/refactor/migration concerns. State categories checked for completeness:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `/var/lib/telldus/telldus-core.conf` (runtime state) | Ensure volume/bind mount for persistence |
| Live service config | None — config is file-based | N/A |
| OS-registered state | None — container is ephemeral | N/A |
| Secrets/env vars | Optional: `TELLDUS_STATE_DIR`, `TELLDUS_CONFIG_FILE` | Document if used, but v1 keeps defaults |
| Build artifacts | Docker image from Phase 5 | Image must exist before Phase 6 testing |

**Nothing found in category:** All categories verified — no migration concerns for this operational phase.

## Common Pitfalls

### Pitfall 1: Device Not Found Due to Missing `--privileged`

**What goes wrong:** Container starts but daemon cannot find TellStick Duo, tdtool shows no devices

**Why it happens:** Without `--privileged`, the container lacks USB device access permissions

**How to avoid:** Always use `--privileged` flag for v1 deployments per D-06-01

**Warning signs:** 
- Log: "Failed to open TellStick"
- `tdtool --list` shows no controllers
- lsusb inside container shows no FTDI devices

### Pitfall 2: State Loss on Container Recreate

**What goes wrong:** After `docker rm telldus && docker run ...`, device states are reset

**Why it happens:** `/var/lib/telldus` not persisted, `telldus-core.conf` recreated empty

**How to avoid:** Use named volume `-v telldus-state:/var/lib/telldus` or bind mount

**Warning signs:** 
- First log message: "Creating state directory /var/lib/telldus"
- Device states revert to default

### Pitfall 3: tdtool Fails Outside Container

**What goes wrong:** Running `tdtool --list` on host fails with "Could not connect to the Telldus Service"

**Why it happens:** Host tdtool looks for `/tmp/TelldusClient` which is container-local

**How to avoid:** Use `docker exec telldus tdtool --list` instead of host tdtool

**Warning signs:** 
- Error: "TELLSTICK_ERROR_CONNECTING_SERVICE"
- `/tmp/TelldusClient` missing on host

### Pitfall 4: Signal Handling Without Proper Init

**What goes wrong:** `docker stop` hangs for 10s then kills container, or leaves zombie processes

**Why it happens:** Running telldusd directly as PID 1 without tini — signals not forwarded properly

**How to avoid:** Ensure ENTRYPOINT includes tini: `ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]`

**Warning signs:** 
- Container takes exactly 10s to stop (Docker timeout)
- Zombie processes visible in `docker top`

### Pitfall 5: Config Changes Require Restart

**What goes wrong:** Editing `/etc/tellstick.conf` on host doesn't reflect in daemon

**Why it happens:** inotify watcher not implemented or not watching correct path (Phase 4 handles this)

**How to avoid:** Verify Phase 4 inotify implementation is active; document that config reload is automatic

**Warning signs:** 
- Device changes don't appear without container restart
- No "Reloading configuration" log messages

## Code Examples

### Example 1: Docker Run Command (Full)

```bash
# Run with all recommended flags
docker run -d \
  --name telldus \
  --privileged \
  --restart unless-stopped \
  -v /path/to/your/tellstick.conf:/etc/tellstick.conf:ro \
  -v telldus-state:/var/lib/telldus \
  telldus:latest
```

**Breakdown:**
- `-d`: Detached/background mode
- `--name telldus`: Predictable name for `docker exec`
- `--privileged`: USB passthrough (v1 pragmatic choice)
- `--restart unless-stopped`: Auto-recovery, respects manual stop
- `-v tellstick.conf:ro`: Host config, read-only after load
- `-v telldus-state`: Named volume for runtime state persistence

### Example 2: docker-compose.yml

```yaml
version: '3.8'

services:
  telldus:
    image: telldus:latest
    container_name: telldus
    privileged: true
    restart: unless-stopped
    volumes:
      - /path/to/your/tellstick.conf:/etc/tellstick.conf:ro
      - telldus-state:/var/lib/telldus
    # Optional: limit resources
    deploy:
      resources:
        limits:
          memory: 64M
          cpus: '0.25'

volumes:
  telldus-state:
    driver: local
```

**Usage:**
```bash
docker-compose up -d
docker-compose exec telldus tdtool --list
```

### Example 3: Shell Alias for Convenience

```bash
# Add to ~/.bashrc or ~/.zshrc
alias tdtool='docker exec telldus tdtool'

# Usage after alias
tdtool --list
tdtool --on 1
tdtool --off Livingroom
```

### Example 4: Checking Container Health

```bash
# Check daemon is running
docker ps | grep telldus

# Check logs
docker logs telldus --tail 50

# Test tdtool communication
docker exec telldus tdtool --list

# Check USB device access inside container
docker exec telldus lsusb | grep -i ftdi
```

### Example 5: Signal Handling Verification

```bash
# Graceful shutdown test
time docker stop telldus
# Should complete in < 2 seconds, not hang for 10s

# Restart
docker start telldus
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Socket bind-mount for host tdtool | `docker exec` pattern | Phase 6 v1 | Cleaner, no path coordination issues, container-native |
| `--device` with udev rules | `--privileged` for v1 | Phase 6 v1 | More reliable for home use, hardening deferred to v2 |
| Static PID file in `/var/run` | PID 1 process management | Phase 5 | Container-native, no file-based PID tracking needed |
| File/syslog logging | stdout/stderr only | Phase 5-6 | Docker-native log aggregation via `docker logs` |

**Deprecated/outdated:**
- Host socket bind-mount: Adds complexity without benefit (D-06-06)
- Dedicated container user: Deferred to v2 security hardening (D-06-15)
- HEALTHCHECK instruction: Manual verification sufficient for v1 (D-06-14)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `--privileged` mode grants sufficient USB access for TellStick Duo | USB Passthrough | If insufficient, need `--device` + udev rules or `--cap-add SYS_RAWIO` |
| A2 | libftdi1 automatically retries USB operations after disconnect | Runtime Resilience | If not, daemon may need restart on USB issues |
| A3 | Socket paths `/tmp/TelldusClient` and `/tmp/TelldusEvents` are container-local and don't conflict with host | IPC Architecture | If host has native telldusd running, paths could conflict if sockets leak to host namespace |
| A4 | `restart: unless-stopped` provides adequate auto-recovery without excessive restart loops | Restart Policy | If daemon crashes immediately, could restart-loop; `--restart on-failure:3` alternative |
| A5 | Docker volume `telldus-state` persists across `docker rm` + `docker run` | State Persistence | If user uses anonymous volume or no volume, state lost on container removal |

## Open Questions

1. **Q: Should we provide a wrapper script for common operations?**
   - What we know: Users will type `docker exec telldus tdtool ...` frequently
   - What's unclear: Whether shell aliases are sufficient or a full wrapper script is needed
   - Recommendation: Provide both — aliases for interactive use, docker-compose for service deployment

2. **Q: How to handle multiple TellStick devices?**
   - What we know: Code supports multiple devices (ControllerManager, list-based)
   - What's unclear: Whether `--privileged` grants access to all USB devices correctly
   - Recommendation: Document that multiple devices are supported, same container handles all

3. **Q: What about log rotation?**
   - What we know: `docker logs` stores logs, can grow unbounded
   - What's unclear: Whether Docker's default log rotation is sufficient
   - Recommendation: Document `docker run --log-opt max-size=10m --log-opt max-file=3` for production

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker Engine | Container runtime | ✓ | 20.10+ | Podman with `--privileged` (untested) |
| tini | PID 1 init | ✓ (in image) | 0.19+ | dumb-init (untested) |
| libftdi1 | USB communication | ✓ (in image) | 1.5+ | ftd2xx (different package) |
| Unix sockets | IPC | ✓ | — | None needed |
| inotify | Config reload | ✓ (Linux) | — | Container restart required |
| `--privileged` | USB passthrough | ✓ (Docker) | — | `--device` + manual udev rules |

**Missing dependencies with no fallback:**
- None — all runtime dependencies are satisfied by the Docker image from Phase 5

**Missing dependencies with fallback:**
- If Docker unavailable: Native Linux install (Phase 2), but Phase 6 scope is containerized runtime

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Shell-based integration tests |
| Config file | `telldus-core/tests/integration/*.sh` (pattern from Phase 4) |
| Quick run command | `docker exec telldus tdtool --list` |
| Full suite command | `scripts/test-container-runtime.sh` (to be created) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCK-02 | TellStick Duo accessible in container | Manual | `docker exec telldus lsusb \| grep -i ftdi` | ❌ Wave 0 |
| DOCK-04 | tdtool works via docker exec | Integration | `docker exec telldus tdtool --list` | ❌ Wave 0 |
| DOCK-05 | Restart preserves config/state | Integration | Stop/start container, verify `tdtool --list` | ❌ Wave 0 |
| DUO-02 | Daemon starts with TellStick connected | Manual | `docker logs telldus` shows success | ❌ Wave 0 |
| DUO-07 | Restart doesn't lose device compatibility | Integration | Restart test + device control test | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Manual verification with `docker exec telldus tdtool --list`
- **Per wave merge:** Full integration test script (if hardware available)
- **Phase gate:** Container runs, tdtool responds, logs show daemon ready

### Wave 0 Gaps

- [ ] `scripts/test-container-runtime.sh` — automated runtime verification
- [ ] `docker-compose.yml` — production deployment template
- [ ] `docs/docker-runtime.md` — operator documentation
- [ ] Shell alias examples in documentation

*(If no gaps: "None — existing test infrastructure covers all phase requirements")*

## Security Domain

> `security_enforcement: false` confirmed — v1 prioritizes reliability over hardening per project scope and D-06-01/02/15

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A — No auth in v1, local USB device only |
| V3 Session Management | No | N/A — No sessions |
| V4 Access Control | Partial | `--privileged` grants full device access (accepted trade-off) |
| V5 Input Validation | Yes | Config file parsing via libconfuse (existing) |
| V6 Cryptography | No | N/A — 433 MHz protocols use no encryption |

### Known Threat Patterns

| Pattern | STRIDE | Mitigation in v1 |
|---------|--------|------------------|
| Container escape via privileged mode | Elevation of Privilege | Accepted risk — single-purpose home automation host |
| Unauthorized USB device access | Information Disclosure | Physical access required, single-user deployment |
| Config file tampering | Tampering | File permissions on host, read-only bind mount |

**Security debt for v2:**
- Replace `--privileged` with `--device` + udev rules (D-06-02)
- Run container as non-root user (D-06-15)
- Implement HEALTHCHECK for availability monitoring
- Add capability dropping (`--cap-drop ALL --cap-add SYS_RAWIO`)

## Sources

### Primary (HIGH confidence)
- `telldus-core/service/main_unix.cpp` — Signal handling, privilege dropping, state directory creation (lines 29-46, 116-128, 130-154)
- `telldus-core/service/TellStick_libftdi.cpp` — USB device opening by VID/PID/serial, error retry logic (lines 57-76, 172-177)
- `telldus-core/common/Socket_unix.cpp` — Unix domain socket implementation at `/tmp/` paths (lines 61-85)
- `telldus-core/service/ConnectionListener_unix.cpp` — Server socket creation, permission setting (lines 32-73)
- `Dockerfile` — Current image structure, tini entrypoint (lines 1-57)
- `scripts/docker-entrypoint.sh` — Smart dispatch logic (lines 1-16)

### Secondary (MEDIUM confidence)
- Phase 5 context (05-CONTEXT.md) — Image contents, multi-arch support, entrypoint decisions
- Phase 4 context (04-CONTEXT.md) — Config reload via inotify, state directory behavior
- Docker documentation — `--privileged`, `--restart`, volume behavior

### Tertiary (LOW confidence)
- libftdi1 internal retry behavior — inferred from code comments and error handling, not explicitly documented in headers
- USB hotplug recovery — not explicitly tested, based on code analysis

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All components verified in codebase or Dockerfile
- Architecture: HIGH — Socket paths, signal handling, entrypoint all inspectable
- Pitfalls: MEDIUM-HIGH — Based on common Docker patterns, some Telldus-specific behavior inferred from code
- USB behavior: MEDIUM — libftdi1 retry logic documented in code but not exhaustively tested

**Research date:** 2026-05-15  
**Valid until:** 90 days or until Dockerfile/entrypoint changes significantly

---

*Phase: 06-Containerized Daemon Runtime*  
*Research file: .planning/phases/06-containerized-daemon-runtime/06-RESEARCH.md*
