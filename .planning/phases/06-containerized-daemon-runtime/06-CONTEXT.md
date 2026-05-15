# Phase 06: Containerized Daemon Runtime - Context

**Gathered:** 2026-05-15T12:00:00Z
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 6 runs `telldusd` and `tdtool` inside Docker with TellStick Duo USB passthrough and restart-safe behavior. The Docker image was built in Phase 5; this phase focuses on runtime operation: USB device passthrough, container process management, tdtool communication patterns, and restart/recovery behavior.

This phase does not modify the Docker image (that's Phase 5), nor does it verify actual hardware operation (that's Phase 7). It defines the operational patterns and documents how to run the container successfully.

</domain>

<decisions>
## Implementation Decisions

### USB Device Passthrough
- **D-06-01:** Use `--privileged` mode for USB passthrough in v1. This provides broad USB access and is the most reliable approach for home/single-use deployment. While it violates least-privilege, it's acceptable for the intended use case (Raspberry Pi/Home Assistant home automation).
- **D-06-02:** Document that production hardening may use udev rules with `--device /dev/tellstick` in v2, but v1 prioritizes reliability over security hardening.
- **D-06-03:** libftdi opens devices by USB vendor/product ID, not device path, so varying `/dev/ttyUSB*` paths between reboots are handled automatically by the library.

### tdtool Communication Pattern
- **D-06-04:** Use `docker exec` pattern as the primary communication method. Example: `docker exec telldus-container tdtool --list`
- **D-06-05:** This is the cleanest container-native approach — no host socket exposure, no library dependencies on the host, consistent with Docker best practices.
- **D-06-06:** Do NOT bind-mount Unix sockets to the host for v1. While possible, it adds complexity and host/container path coordination issues.

### Container Process Management
- **D-06-07:** The Dockerfile already uses `tini` as PID 1 for proper signal forwarding and zombie reaping (from Phase 5).
- **D-06-08:** The daemon runs with `--nodaemon` flag for foreground operation, ensuring logs go to stdout/stderr and are captured by `docker logs`.
- **D-06-09:** Signal handling: SIGTERM/SIGINT trigger graceful shutdown (existing daemon behavior). SIGHUP is logged but doesn't reload config (config reload is via inotify from Phase 4).

### Restart & Recovery Behavior
- **D-06-10:** Use `restart: unless-stopped` policy. Container auto-restarts on daemon crash or host reboot, but respects manual `docker stop`.
- **D-06-11:** USB disconnect/reconnect is handled internally by libftdi retries — container keeps running. The daemon does not exit on USB errors.
- **D-06-12:** State persistence is already ensured by Phase 4 (`/var/lib/telldus/telldus-core.conf` survives container restart via volume or bind mount).
- **D-06-13:** Config auto-reload is handled by inotify watcher (Phase 4) — no container restart needed for config changes.

### Operational Simplicity
- **D-06-14:** No HEALTHCHECK for v1. Health verification is done via manual `docker exec` commands or Phase 7 hardware verification.
- **D-06-15:** Run as root in container for v1 (matching Phase 4's deferral of dedicated telldus user to v2). The daemon internally drops privileges based on tellstick.conf user/group settings.
- **D-06-16:** Logging goes to stdout/stderr only. No syslog, no log files in container. `docker logs` is the primary log access method.
- **D-06-17:** No additional environment variables for log level or configuration. Use existing `TELLDUS_CONFIG_FILE` and `TELLDUS_STATE_DIR` from Phase 4 if needed.

### Agent's Discretion
- The agent may structure the run documentation (docker run command, docker-compose.yml) in the most readable format.
- The agent may add example shell aliases or wrapper scripts to simplify `docker exec` commands if they improve usability.
- The agent may recommend specific `--name` values for containers to make `docker exec` commands predictable.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Scope
- `.planning/PROJECT.md` — Defines Linux-only headless modernization, Docker/native goals, and out-of-scope items
- `.planning/REQUIREMENTS.md` — Maps Phase 6 to DOCK-02, DOCK-04, DOCK-05, DUO-02, DUO-07
- `.planning/ROADMAP.md` — Defines Phase 6 goal, success criteria, and plan outline
- `.planning/STATE.md` — Current project position and deferred items

### Prior Phase Context (Critical)
- `.planning/phases/05-docker-image-and-config-mount/05-CONTEXT.md` — Docker image structure, entrypoint behavior, multi-arch support
- `.planning/phases/04-config-compatibility/04-CONTEXT.md` — Config/state paths, auto-reload via inotify, env var overrides
- `.planning/phases/03-raspberry-pi-portability/03-CONTEXT.md` — Debian/aarch64 runtime considerations
- `.planning/phases/02-arch-native-build/02-CONTEXT.md` — Build artifacts and library dependencies

### Codebase Maps
- `.planning/codebase/STACK.md` — Build systems, dependencies (libftdi1, libconfuse), component boundaries
- `.planning/codebase/ARCHITECTURE.md` — Service/client architecture, IPC via Unix sockets
- `.planning/codebase/INTEGRATIONS.md` — Hardware integration boundaries

### Source Entry Points
- `Dockerfile` — Multi-stage build, tini init, entrypoint script location
- `scripts/docker-entrypoint.sh` — Smart dispatch between telldusd and tdtool
- `telldus-core/service/main_unix.cpp` — Signal handling, privilege dropping, state directory creation
- `telldus-core/service/ConnectionListener_unix.cpp` — Unix socket creation at `/tmp/TelldusClient`
- `telldus-core/client/Client.cpp` — Client connection to daemon sockets
- `telldus-core/common/Socket_unix.cpp` — Unix domain socket implementation
- `telldus-core/service/TellStick_libftdi.cpp` — USB device access via libftdi

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Dockerfile` (from Phase 5): Already includes tini, entrypoint script, and runtime libraries. Ready for runtime use.
- `scripts/docker-entrypoint.sh`: Smart dispatch already handles `tdtool`, `tdadmin`, and `telldusd --nodaemon` cases.
- Socket paths: Daemon creates `/tmp/TelldusClient` and `/tmp/TelldusEvents` — these exist only within the container namespace.
- Signal handling: `main_unix.cpp` handles SIGTERM/SIGINT for graceful shutdown, SIGPIPE is ignored.

### Established Patterns
- Container as PID 1: tini → entrypoint.sh → telldusd --nodaemon
- Logging: All goes to stdout when --nodaemon is used (setLogOutput(Log::StdOut) in main_unix.cpp)
- USB access: libftdi opens by vendor/product ID, making device path changes transparent
- State persistence: `/var/lib/telldus` should be a volume or bind mount for state survival
- Config mounting: `/etc/tellstick.conf` is bind-mounted from host (established in Phase 5)

### Integration Points
- Container start: Entrypoint script runs, telldusd starts with --nodaemon
- tdtool access: `docker exec <container> tdtool <args>` connects to running daemon via Unix sockets
- USB access: Requires --privileged or --device for TellStick Duo FTDI access
- State storage: Container should have `/var/lib/telldus` as a volume for persistence
- Config updates: inotify watcher (Phase 4) detects changes without container restart

</code_context>

<specifics>
## Specific Ideas

- The user explicitly chose `--privileged` for USB passthrough as a pragmatic v1 choice, accepting the security trade-off for reliability.
- `docker exec` pattern was chosen over socket bind-mount for cleanliness — no host/container path coordination issues.
- `restart: unless-stopped` balances automation (auto-recovery) with operator control (manual stop respected).
- Simplicity was prioritized: no healthcheck, no additional env vars, root user in container — all deferred to v2 hardening.

</specifics>

<deferred>
## Deferred Ideas

- **udev rules with --device** — Production hardening for v2: create stable `/dev/tellstick` symlink, use `--device` instead of `--privileged`
- **Dedicated telldus user in container** — Security hardening deferred to v2 packaging
- **HEALTHCHECK instruction** — Container health verification deferred; manual verification via `docker exec` is acceptable for v1
- **Socket bind-mount for host tdtool** — Advanced use case for v2 if users want native tdtool feel
- **Environment variable configuration** — TELLDUS_LOG_LEVEL, etc. — can be added in v2 if needed

</deferred>

---

*Phase: 06-Containerized Daemon Runtime*
*Context gathered: 2026-05-15T12:00:00Z*
