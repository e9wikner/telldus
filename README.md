# Telldus Core Modern Linux Support

Modernized Telldus Core for headless Linux operation on Arch Linux and Raspberry Pi OS/Debian aarch64.

**Core value:** Existing 433 MHz devices controlled by a TellStick Duo keep working on modern Linux using your existing `/etc/tellstick.conf`, without re-pairing devices.

---

## Overview

This project restores Telldus Core runtime on current Linux systems. The primary use case is running a TellStick Duo for 433 MHz home automation devices on Arch Linux (development) or Raspberry Pi OS/Debian aarch64 (deployment near Home Assistant).

**What this provides:**
- Headless daemon (`telldusd`) without TelldusCenter or Qt dependencies
- Docker container with config bind-mount and USB passthrough
- Native builds for Arch Linux and Raspberry Pi OS/Debian
- `tdtool` CLI for device control and verification
- Full compatibility with existing `tellstick.conf` files

**What's deferred to v2:**
- MQTT bridge and Home Assistant integration
- TelldusCenter/Qt GUI (not supported in v1)
- Windows, macOS, FreeBSD support (Linux-only in v1)
- Native packaging (APK/DEB packages)

---

## Prerequisites

### Hardware
- TellStick Duo USB device (VID:PID 1781:0c31)
- Existing `tellstick.conf` with your paired devices

### Software (choose one path)
- **Docker:** Docker 20.10+ with Docker Compose
- **Native Arch Linux:** `pacman`, `cmake`, `gcc`
- **Native Raspberry Pi OS/Debian:** `apt`, `cmake`, `build-essential`

### Required Files
- Your existing `tellstick.conf` configuration file

---

## Docker Quickstart

The fastest way to get running:

```bash
# 1. Build the Docker image
./scripts/build-docker.sh --load

# 2. Configure your tellstick.conf path (edit the script first)
./scripts/run-telldus.sh

# 3. Verify it's working
docker exec telldus tdtool --list
```

See [Docker Operation](#docker-operation) for detailed usage and [Verification](#verification) for testing.

---

## Docker Operation

### Building the Image

```bash
# Build for local use (linux/amd64)
./scripts/build-docker.sh --load

# Build and push multi-platform (linux/amd64,linux/arm64)
./scripts/build-docker.sh --push ghcr.io/YOUR_USERNAME
```

### Running with Docker

The helper script handles the full setup:

```bash
# Edit CONFIG_PATH in scripts/run-telldus.sh first, then:
./scripts/run-telldus.sh
```

Or run directly:

```bash
docker run -d \
    --name telldus \
    --privileged \
    --restart unless-stopped \
    -v /path/to/your/tellstick.conf:/etc/tellstick.conf:ro \
    -v telldus-state:/var/lib/telldus \
    telldus:latest
```

**Flags explained:**
- `--privileged`: Required for USB passthrough (TellStick Duo access)
- `--restart unless-stopped`: Auto-recovery from crashes and reboots
- `-v tellstick.conf:ro`: Read-only config bind mount
- `-v telldus-state`: Named volume for state persistence

### Using Docker Compose

```bash
# Edit docker-compose.yml first to set your config path
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs --tail 50

# Execute tdtool
docker-compose exec telldus tdtool --list
```

### Using tdtool via docker exec

```bash
# List devices and sensors
docker exec telldus tdtool --list

# Turn device on/off (by ID or name)
docker exec telldus tdtool --on 1
docker exec telldus tdtool --off Livingroom

# Dim a device
docker exec telldus tdtool --dimlevel 128 --dim 1

# List only devices or sensors
docker exec telldus tdtool --list-devices
docker exec telldus tdtool --list-sensors
```

**Tip:** Add an alias for convenience:
```bash
alias tdtool='docker exec telldus tdtool'
```

### Container Lifecycle

```bash
# View logs
docker logs telldus --tail 50
docker logs telldus --follow

# Stop gracefully (should complete in < 2 seconds)
docker stop telldus

# Start after stop
docker start telldus

# Restart
docker restart telldus

# Remove container (state is preserved in volume)
docker stop telldus && docker rm telldus
```

### State Persistence

Device states and learned devices persist across container restarts via the named volume `telldus-state` mounted at `/var/lib/telldus`. State is written automatically on every device state change.

---

## Native Build - Arch Linux

### 1. Install Dependencies

```bash
./scripts/install-arch-deps.sh
```

This installs: `cmake`, `gcc`, `make`, `libftdi`, `confuse`, `libusb-compat`, `pkg-config`, `cppunit`

### 2. Build

```bash
# Configure with headless preset
cmake --preset headless

# Build
cmake --build build/headless --parallel $(nproc)
```

### 3. Run Tests

```bash
cd build/headless && ctest -R cppunit --output-on-failure
```

### 4. Run Daemon

```bash
# Start the daemon (requires root for USB access)
sudo ./build/headless/telldus-core/service/telldusd

# In another terminal, use tdtool
./build/headless/telldus-core/tdtool/tdtool --list
```

---

## Native Build - Raspberry Pi OS/Debian

### 1. Install Dependencies

```bash
./scripts/install-debian-deps.sh
```

This installs: `cmake`, `build-essential`, `pkg-config`, `libftdi1-dev`, `libconfuse-dev`, `libusb-1.0-0-dev`, `libcppunit-dev`

### 2. Build

```bash
# Use the same headless preset (architecture-agnostic)
cmake --preset headless

# Single-threaded build recommended for low-memory systems
cmake --build build/headless --parallel 1
```

### 3. Run

```bash
# Start the daemon
sudo ./build/headless/telldus-core/service/telldusd

# Use tdtool
./build/headless/telldus-core/tdtool/tdtool --list
```

---

## Configuration

### tellstick.conf Location

- **Docker:** Mounted from host to `/etc/tellstick.conf`
- **Native:** System path `/etc/tellstick.conf`

### Config Format

Your existing `tellstick.conf` works unchanged:

```
device {
    id = 1
    name = "Living Room"
    protocol = "arctech"
    model = "selflearning-switch"
    parameters {
        house = "12345678"
        unit = "1"
    }
}
```

### Config Auto-Reload

The daemon watches `/etc/tellstick.conf` via inotify. Changes are applied automatically within 1-2 seconds of saving the file. No container restart required.

### State File

- **Location:** `/var/lib/telldus/telldus-core.conf`
- **Purpose:** Stores device states (on/off/dim values)
- **Persistence:** Docker volume or host directory for native builds

---

## Verification

See [docs/verification-checklist.md](docs/verification-checklist.md) for the complete hardware verification checklist.

### Quick Verification

```bash
# 1. Check container is running
docker ps | grep telldus

# 2. Verify USB detection
docker exec telldus lsusb | grep "1781:0c31"

# 3. List configured devices
docker exec telldus tdtool --list

# 4. Test device control (observe physical device)
docker exec telldus tdtool --on 1
docker exec telldus tdtool --off 1
```

### Automated Verification

```bash
# USB detection only
./scripts/verify-usb-detection.sh

# Full hardware verification
./scripts/verify-tellstick-hardware.sh
```

---

## Troubleshooting

### USB Not Detected

| Check | Command |
|-------|---------|
| Host detection | `lsusb \| grep 1781:0c31` |
| Container detection | `docker exec telldus lsusb \| grep 1781:0c31` |
| Privileged flag | `docker inspect telldus \| grep Privileged` |

**Solution:** Ensure `--privileged` flag is used when running the container.

### Config File Not Found

**Symptom:** Container exits immediately

```bash
# Check logs
docker logs telldus

# Verify config file exists
ls -la /path/to/your/tellstick.conf
```

**Solution:** Update `CONFIG_PATH` in `scripts/run-telldus.sh` or edit `docker-compose.yml` with your actual config path.

### Permission Issues

**Symptom:** "Could not connect to the Telldus Service"

```bash
# Check daemon is running
docker top telldus

# View logs for errors
docker logs telldus --tail 50
```

### Container Won't Start

```bash
# View logs for startup errors
docker logs telldus

# Common causes:
# - Missing config file
# - Config syntax errors
# - USB permissions
```

### Device Commands Fail

| Exit Code | Meaning | Solution |
|-----------|---------|----------|
| 1 | General error | Check `docker logs telldus` |
| 3 | Device not found | Verify device ID with `tdtool --list` |
| 6 | Service error | Daemon not running, check logs |

---

## What's Next

### v2 Roadmap

These features are planned for the next milestone:

- **MQTT bridge:** Home Assistant MQTT discovery integration
- **Native packaging:** systemd service, APK/DEB packages
- **Multi-arch images:** Published images for amd64/arm64

### Not in v1

- **TelldusCenter/Qt GUI:** Not supported, headless only
- **Windows/macOS/FreeBSD:** Linux-only in v1
- **MQTT bridge:** Deferred to v2 milestone
- **Home Assistant integration:** Deferred to v2 milestone
- **Native packaging:** systemd service, APK/DEB packages deferred to v2
- **Device pairing UI:** Use existing `tellstick.conf`

### Project Documentation

- [PROJECT.md](.planning/PROJECT.md) - Full project context and decisions
- [ROADMAP.md](.planning/ROADMAP.md) - Phase-by-phase roadmap
- [docs/REPOSITORY.md](docs/REPOSITORY.md) - Repository and docs folder organization
- [docs/verification-checklist.md](docs/verification-checklist.md) - Hardware verification

---

## License

See the COPYING file in the repository for license information.
