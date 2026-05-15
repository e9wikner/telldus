# Telldus Docker Runtime Guide

This document describes how the Telldus daemon runs inside a Docker container, including process architecture, signal handling, logging, startup, and shutdown procedures.

## Overview

The Telldus container runs `telldusd` as its main process with proper signal handling and foreground operation. This design ensures Docker-native lifecycle management and log aggregation.

## Process Architecture

The container uses a layered process hierarchy for robust signal handling and proper PID 1 behavior:

```
tini (PID 1) → docker-entrypoint.sh → telldusd --nodaemon
```

### Component Roles

| Component | Role | Purpose |
|-----------|------|---------|
| **tini** | PID 1 Init System | Forwards signals to child processes, reaps zombie processes, ensures clean container shutdown |
| **docker-entrypoint.sh** | Smart Dispatch | Routes `docker exec` commands to tdtool/tdadmin, or starts telldusd daemon |
| **telldusd --nodaemon** | Main Process | Runs daemon in foreground (not background), receives signals directly, logs to stdout/stderr |

### Why tini as PID 1

The Dockerfile uses `tini` as the init system (via `ENTRYPOINT ["/usr/bin/tini", "--", ...]`):

- **Signal forwarding**: Properly forwards SIGTERM/SIGINT from Docker to telldusd
- **Zombie reaping**: Prevents accumulation of zombie processes from client connections
- **Graceful shutdown**: Ensures clean daemon termination on `docker stop`

### Why --nodaemon Mode

The container runs telldusd with `--nodaemon` flag:

- **Foreground operation**: Process remains attached to container's stdout/stderr
- **Docker log compatibility**: Logs appear in `docker logs` output
- **Direct signal reception**: SIGTERM/SIGINT received immediately by daemon
- **No PID file management**: Container runtime manages process lifecycle

## Signal Handling

The daemon handles signals for graceful shutdown and container lifecycle management.

### Supported Signals

| Signal | Handler | Behavior |
|--------|---------|----------|
| **SIGTERM** | Graceful shutdown | Logs shutdown message, stops event loop, closes USB handles, exits cleanly |
| **SIGINT** | Graceful shutdown | Same as SIGTERM (for interactive interrupt) |
| **SIGHUP** | Log and continue | Logs receipt but does not restart daemon |
| **SIGPIPE** | Ignored | Prevents crashes from broken pipe errors |

### Graceful Shutdown Flow

When `docker stop` is issued:

1. Docker sends **SIGTERM** to container PID 1 (tini)
2. tini forwards SIGTERM to telldusd process
3. `signalHandler(SIGTERM)` logs "Received SIGTERM or SIGINT signal. Shutting down"
4. `TelldusMain::stop()` signals event handler to exit
5. Controller threads stop, USB handles closed
6. Unix sockets `/tmp/TelldusClient` and `/tmp/TelldusEvents` unlinked
7. Log message: "telldusd daemon exited"
8. Container exits with code 0

### Shutdown Timeout

Docker's default stop timeout is **10 seconds**, after which SIGKILL is sent. The daemon typically shuts down in **< 1 second**, so the 10-second timeout should never be reached under normal circumstances.

**Verification:**
```bash
time docker stop telldus
# Should complete in < 2 seconds
```

## Logging

The daemon logs to **stdout/stderr only** when running with `--nodaemon` mode. This is the Docker-native logging approach.

### Log Access

View container logs using standard Docker commands:

```bash
# View recent logs
docker logs telldus --tail 50

# Follow logs in real-time
docker logs telldus --follow

# View logs with timestamps
docker logs telldus --timestamps

# View all logs since container start
docker logs telldus
```

### Log Content

Typical log output includes:

```
telldusd daemon starting up
[Controller discovery messages]
[TellStick detection: VID/PID/Serial]
[Device list loaded from /etc/tellstick.conf]
[Socket listening on /tmp/TelldusClient]
[Sensors detected: ...]
```

### Log Rotation

Docker handles log rotation automatically. For production deployments, configure log limits:

```bash
docker run --log-opt max-size=10m --log-opt max-file=3 ...
```

### No File-Based Logging

Do not expect log files inside the container. All logging goes through Docker's logging driver (json-file by default, or your configured driver).

## Startup Procedure

### Container Startup Sequence

When the container starts, this sequence executes:

1. **Container creation** with `--privileged` for USB access
2. **Bind mounts applied**:
   - `/etc/tellstick.conf` (host config)
   - `/var/lib/telldus` (state persistence)
3. **tini starts** as PID 1
4. **entrypoint.sh** executes with default CMD `["telldusd", "--nodaemon"]`
5. **telldusd starts**:
   - Logs "telldusd daemon starting up"
   - Creates state directory if needed
   - Creates Unix sockets at `/tmp/TelldusClient` and `/tmp/TelldusEvents`
   - libftdi1 scans USB for TellStick Duo
   - Loads device list from `/etc/tellstick.conf`
6. **Daemon ready** - accepts tdtool commands via docker exec

### Startup Verification Checklist

After starting the container, verify successful startup:

```bash
# 1. Check container is running
docker ps | grep telldus

# Expected output:
# CONTAINER ID   IMAGE           COMMAND                  CREATED          STATUS          PORTS     NAMES
# a1b2c3d4e5f6   telldus:latest  "/usr/bin/tini -- /u..." 10 seconds ago   Up 9 seconds              telldus

# 2. Check logs for startup messages
docker logs telldus --tail 20

# Expected log entries:
# - "telldusd daemon starting up"
# - TellStick detection (if connected): "TellStick Duo found at bus..."
# - Device list loading
# - "Listening on /tmp/TelldusClient"

# 3. Verify daemon readiness with tdtool
docker exec telldus tdtool --list

# Expected output (example):
# Number of devices: 3
# 1	Livingroom	dimmer	off
# 2	Kitchen		onoff		on
# 3	Porch		onoff		off

# 4. Check USB device access (if TellStick connected)
docker exec telldus lsusb | grep -i ftdi

# Expected: FTDI device listed (e.g., "Bus 001 Device 003: ID 1781:0c31...")
```

### Docker Run Command

Complete startup command with recommended flags:

```bash
docker run -d \
  --name telldus \
  --privileged \
  --restart unless-stopped \
  -v /path/to/your/tellstick.conf:/etc/tellstick.conf:ro \
  -v telldus-state:/var/lib/telldus \
  telldus:latest
```

**Flag explanations:**
- `-d`: Detached/background mode
- `--name telldus`: Predictable container name for `docker exec`
- `--privileged`: USB passthrough for TellStick Duo
- `--restart unless-stopped`: Auto-recovery on crash/reboot, respects manual stop
- `-v tellstick.conf:ro`: Read-only config bind mount
- `-v telldus-state`: Named volume for runtime state persistence

### Docker Compose Startup

Using docker-compose.yml:

```bash
# Start container
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs --tail 50

# Execute tdtool
docker-compose exec telldus tdtool --list
```

## Using tdtool

The `tdtool` command provides device control and status information. When running Telldus in a Docker container, use the `docker exec` pattern to execute tdtool commands inside the container.

### Primary Pattern: docker exec

The recommended way to use tdtool with a containerized daemon is via `docker exec`:

```bash
docker exec telldus tdtool --list
```

This pattern is cleaner than bind-mounting Unix sockets to the host because:
- **No socket path coordination** - Sockets remain container-local at `/tmp/TelldusClient`
- **No host dependencies** - Host doesn't need telldus-core library installed
- **Container-native** - Follows Docker best practices for sidecar tooling
- **Consistent behavior** - Works identically across all host platforms

Per decision D-06-04, this is the primary v1 communication method. Socket bind-mount to host is deferred to v2.

### Common Commands

**List all devices and sensors:**
```bash
docker exec telldus tdtool --list
```

**Turn on a device (by ID or name):**
```bash
docker exec telldus tdtool --on 1
docker exec telldus tdtool --on Livingroom
```

**Turn off a device (by ID or name):**
```bash
docker exec telldus tdtool --off 1
docker exec telldus tdtool --off Livingroom
```

**Dim a device:**
```bash
docker exec telldus tdtool --dimlevel 128 --dim 1
```

**Send bell command:**
```bash
docker exec telldus tdtool --bell 1
```

**List only devices (key=value format):**
```bash
docker exec telldus tdtool --list-devices
```

**List only sensors (key=value format):**
```bash
docker exec telldus tdtool --list-sensors
```

### Why Host tdtool Doesn't Work

Running `tdtool --list` directly on the host will fail with:
```
Could not connect to the Telldus Service
```

This happens because:
1. Host tdtool looks for Unix socket at `/tmp/TelldusClient`
2. The container's daemon creates sockets inside the container namespace
3. These sockets are not visible on the host filesystem

**Solution:** Always use `docker exec telldus tdtool <args>`

### Shell Aliases for Convenience

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
alias tdtool='docker exec telldus tdtool'
```

Then use tdtool as if it were installed locally:
```bash
tdtool --list
tdtool --on 1
tdtool --off Livingroom
```

For docker-compose deployments:
```bash
alias tdtool='docker-compose exec telldus tdtool'
```

## Shutdown Procedure

### Graceful Shutdown

Stop the container gracefully (recommended):

```bash
# Graceful shutdown with timeout display
time docker stop telldus

# Expected output:
# real    0m0.8s
# user    0m0.0s
# sys     0m0.1s
```

A shutdown time **< 2 seconds** indicates successful graceful shutdown. If it takes exactly 10 seconds, check the troubleshooting section.

### Quick Stop (SIGKILL)

Force immediate termination (may lose in-flight commands):

```bash
docker kill telldus
```

Use only when graceful shutdown hangs.

### Restart Procedures

**Option 1: Stop and Start (preserves state)**
```bash
# Graceful stop
docker stop telldus

# Start again (state preserved in volume)
docker start telldus
```

**Option 2: Single restart command**
```bash
docker restart telldus
```

**Option 3: Full recreate (state lost unless volume used)**
```bash
docker stop telldus
docker rm telldus
docker run -d --name telldus --privileged \
  -v /path/to/your/tellstick.conf:/etc/tellstick.conf:ro \
  -v telldus-state:/var/lib/telldus \
  telldus:latest
```

### State Persistence

Runtime state is preserved across container restarts when using a volume:

```bash
# Verify state persisted after restart
docker exec telldus tdtool --list
# Device states should match pre-shutdown values
```

State includes:
- Device on/off/dim values
- Last known sensor readings
- Controller connection status

State is stored in `/var/lib/telldus/telldus-core.conf` (inside the volume).

### Configuration Changes Without Restart

The daemon supports **hot config reload** via inotify (implemented in Phase 4):

1. Edit `/path/to/your/tellstick.conf` on host
2. Save file triggers `IN_CLOSE_WRITE` event
3. Daemon detects change and reloads configuration
4. New devices appear in `tdtool --list` immediately
5. No container restart required

**Note:** Config changes are automatic. No manual restart needed for adding/removing devices.

## Troubleshooting

### Container Won't Start

**Symptom:** `docker ps` doesn't show container, or STATUS is `Exited`

**Check logs:**
```bash
docker logs telldus
```

**Common causes:**
- Missing config file: Ensure `/path/to/your/tellstick.conf` exists on host
- Permissions: Check config file is readable
- Syntax errors: Validate tellstick.conf syntax (see Phase 4 docs)

### TellStick Not Detected

**Symptom:** Logs show no TellStick detection, `tdtool --list` shows no controllers

**Verification:**
```bash
# Check USB device visibility inside container
docker exec telldus lsusb

# Should show: Bus XXX Device YYY: ID 1781:0c31 Future Technology ...
```

**Common causes:**
- Missing `--privileged` flag on `docker run`
- TellStick not physically connected
- USB permissions on host

**Solution:** Ensure container started with `--privileged`

### Failed to open TellStick

**Symptom:** Logs show `Failed to open TellStick` error

**Cause:** USB device access issue - container lacks permissions to open the FTDI device

**Diagnosis:**
```bash
# Check if FTDI device is visible
docker exec telldus lsusb | grep -i ftdi

# Check container privileges
docker inspect telldus --format='{{.HostConfig.Privileged}}'
# Should show: true
```

**Common causes:**
- Missing `--privileged` flag on `docker run`
- TellStick physically disconnected
- USB port/cable issue
- Another process has device open

**Solution:**
```bash
# 1. Stop and remove existing container
docker stop telldus && docker rm telldus

# 2. Re-run with --privileged flag
docker run -d \
  --name telldus \
  --privileged \
  -v /path/to/your/tellstick.conf:/etc/tellstick.conf:ro \
  -v telldus-state:/var/lib/telldus \
  telldus:latest

# 3. Verify USB access
docker exec telldus lsusb | grep -i ftdi
```

### No Devices Listed

**Symptom:** `tdtool --list` shows `Number of devices: 0` or no devices

**Cause:** Config file not mounted correctly or syntax errors

**Diagnosis:**
```bash
# Check if config file is accessible in container
docker exec telldus cat /etc/tellstick.conf

# Check config file permissions on host
ls -la /path/to/your/tellstick.conf

# View logs for config parsing errors
docker logs telldus | grep -i "config\|device"
```

**Common causes:**
- Config file path incorrect in bind mount
- Config file permissions not readable
- Syntax errors in tellstick.conf
- Config file not on host filesystem

**Solution:**
```bash
# 1. Verify config file exists on host
ls -la /path/to/your/tellstick.conf

# 2. Check file permissions (should be readable)
chmod 644 /path/to/your/tellstick.conf

# 3. Validate config syntax (basic check)
grep -E '^device|^controller' /path/to/your/tellstick.conf

# 4. Recreate container with correct path
docker stop telldus && docker rm telldus
docker run -d \
  --name telldus \
  --privileged \
  -v /path/to/your/tellstick.conf:/etc/tellstick.conf:ro \
  -v telldus-state:/var/lib/telldus \
  telldus:latest

# 5. Verify devices loaded
docker exec telldus tdtool --list
```

### tdtool Connection Failed

**Symptom:** `docker exec telldus tdtool --list` returns:
```
Could not connect to the Telldus Service
```

**Common causes:**
- Daemon not yet started (wait a few seconds after container start)
- Daemon crashed (check `docker logs telldus`)
- Socket permissions issue

**Solution:**
```bash
# Check if daemon is running
docker top telldus

# Check logs for errors
docker logs telldus --tail 50

# Restart container if needed
docker restart telldus
```

### Shutdown Hangs (10 Second Delay)

**Symptom:** `docker stop telldus` takes exactly 10 seconds

**Cause:** Signal handling not working, Docker sends SIGKILL after timeout

**Diagnosis:**
```bash
# Check current entrypoint
docker inspect telldus --format='{{.Config.Entrypoint}}'

# Should show: [/usr/bin/tini -- /usr/local/bin/docker-entrypoint.sh]
```

**Solution:** Ensure Dockerfile uses tini as ENTRYPOINT (see Dockerfile reference)

### State Lost After Restart

**Symptom:** Device states reset after `docker stop && docker start`

**Cause:** No volume mounted for `/var/lib/telldus`

**Solution:** Add state volume:
```bash
docker run ... -v telldus-state:/var/lib/telldus ...
```

### Config Changes Not Applied

**Symptom:** Edited tellstick.conf but changes not reflected in `tdtool --list`

**Diagnosis:**
```bash
# Check if inotify watcher is active (requires debugging build)
docker logs telldus | grep -i "reload\|inotify"
```

**Solution:** If config auto-reload not working, restart container:
```bash
docker restart telldus
```

## Quick Reference

### Essential Commands

```bash
# Start container
docker run -d --name telldus --privileged \
  -v /path/to/your/tellstick.conf:/etc/tellstick.conf:ro \
  -v telldus-state:/var/lib/telldus \
  telldus:latest

# Check status
docker ps | grep telldus

# View logs
docker logs telldus --tail 50

# List devices
docker exec telldus tdtool --list

# Turn device on/off
docker exec telldus tdtool --on <device_id>
docker exec telldus tdtool --off <device_id>

# Stop container
docker stop telldus

# Start stopped container
docker start telldus

# Restart container
docker restart telldus

# Shell alias for convenience
alias tdtool='docker exec telldus tdtool'
```

### Shell Alias Setup

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias tdtool='docker exec telldus tdtool'
```

Then use normally:
```bash
tdtool --list
tdtool --on 1
tdtool --off Livingroom
```

## References

- [Dockerfile](../../Dockerfile) - Container image definition
- [docker-entrypoint.sh](../../scripts/docker-entrypoint.sh) - Smart dispatch script
- [06-RESEARCH.md](../.planning/phases/06-containerized-daemon-runtime/06-RESEARCH.md) - Phase 6 research notes
- [telldus-core/service/main_unix.cpp](../../telldus-core/service/main_unix.cpp) - Signal handling implementation
