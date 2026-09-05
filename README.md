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
- `telldus-mqtt` bridge with Home Assistant MQTT discovery (switches, lights,
  covers, buttons, and sensors) — see [MQTT / Home Assistant Bridge](#mqtt--home-assistant-bridge)

**What's deferred beyond v2:**
- TelldusCenter/Qt GUI (not supported)
- Windows, macOS, FreeBSD support (Linux-only)
- Native packaging (APK/DEB packages, systemd service)

---

## Prerequisites

### Hardware
- TellStick Duo USB device (VID:PID 1781:0c31)
- Existing `tellstick.conf` with your paired devices

### Software (choose one path)
- **Docker:** Docker 20.10+ with Docker Compose
- **Rootless Podman:** Podman 4+ (see [Rootless Podman quadlet](#rootless-podman-quadlet-hubbabubba))
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

## Rootless Podman quadlet (hubbabubba)

A fourth deployment path, alongside Docker and the two native builds: a
rootless Podman quadlet running as a `systemd --user` unit, with no root
daemon, no `docker` group, and no `--privileged`. It is what runs on the
`hubbabubba` home server, deployed from a checkout of this repo on that host:

```bash
cd ~/Development/telldus
cp deploy/deploy.env.example deploy/deploy.env          # broker credentials
cp deploy/tellstick.conf.example deploy/tellstick.conf  # device pairing
deploy/deploy.sh
```

`deploy/deploy.sh` builds the image, renders the quadlet, and manages the
unit. It uses no `sudo` — the USB access that Docker gets from `--privileged`
comes instead from a udev ACL on the TellStick's node plus a user-namespace
mapping that keeps `nobody` on the deploying account's own uid.

See [deploy/README.md](deploy/README.md) for what the host has to provide,
the deploy/rollback loop, and verification.

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

## MQTT / Home Assistant Bridge

`telldus-mqtt` is a second process that runs in the same container as
`telldusd`. It publishes your configured devices and any sensors the Duo
receives to MQTT with Home Assistant discovery, so they appear as HA
entities automatically — `tdtool` keeps working unchanged alongside it.

### Enabling it

**Docker Compose:** uncomment `command: telldus-mqtt` and the `MQTT_*`
environment block in `docker-compose.yml`, set `MQTT_BROKER_HOST`, then
`docker-compose up -d`.

**`run-telldus.sh`:** set `MQTT_BROKER_HOST` (and any other `MQTT_*`
variables) before running the script — it switches from the plain daemon to
the bridge automatically:

```bash
CONFIG_PATH=/etc/tellstick.conf MQTT_BROKER_HOST=mqtt.lan \
  ./scripts/run-telldus.sh
```

### Configuration (environment variables)

| Variable | Default | Purpose |
|---|---|---|
| `MQTT_BROKER_HOST` | `localhost` | Also the switch that enables the bridge in `run-telldus.sh` |
| `MQTT_BROKER_PORT` | `1883` | Broker port |
| `MQTT_USERNAME` / `MQTT_PASSWORD` | *(none)* | Broker auth, if required |
| `MQTT_CLIENT_ID` | `telldus-mqtt-<hostname>` | MQTT client ID |
| `MQTT_TLS_CA` | *(none)* | Path to a CA bundle, to connect over TLS |
| `MQTT_TOPIC_PREFIX` | `telldus` | State/command topic prefix |
| `MQTT_DISCOVERY_PREFIX` | `homeassistant` | HA discovery topic prefix |
| `MQTT_QOS` | `1` | QoS for publishes/subscribes |
| `MQTT_LOG_LEVEL` | *(none)* | Set to `debug` for verbose logging |
| `MQTT_RAW_EVENTS` | `0` | Set to `1`/`true` to publish `<prefix>/raw` (non-retained), for debugging unrecognized frames |

### Topic scheme

```
telldus/bridge/status                              online | offline   (retained, LWT)
telldus/device/<id>/state                          ON | OFF           (retained)
telldus/device/<id>/brightness                     0-255              (retained, dimmers)
telldus/device/<id>/set                            ON | OFF | TOGGLE  (subscribed)
telldus/device/<id>/brightness/set                 0-255              (subscribed)
telldus/device/<id>/cover/set                       OPEN|CLOSE|STOP    (subscribed)
telldus/sensor/<protocol>/<model>/<id>/<datatype>  numeric value      (retained)
```

Devices (switches, dimmers, covers, buttons — from your `tellstick.conf`)
publish discovery and state at startup. Sensors are **runtime-discovered
only**: they are never in `tellstick.conf`, so a sensor's discovery and
state topics appear the first time the Duo receives a packet from it.
Discovery and retained state are republished on every broker reconnect.

### Device state is optimistic

433 MHz transmission is fire-and-forget — there is no acknowledgement from
the physical device. `telldus/device/<id>/state` reflects the last command
the bridge (or `tdtool`, or anything else) **sent**, via
`tdLastSentCommand`, not a confirmed reading. If a device is also switched
by its original physical remote, MQTT/HA will read the wrong state unless
that remote is itself configured as a receiving device in `tellstick.conf`.
Sensor readings, by contrast, are genuine received values.

### Pairing is not exposed

The bridge never calls `tdSetName`, `tdAddDevice`, `tdRemoveDevice`, or
`tdLearn` — device IDs and pairing come entirely from your existing
`tellstick.conf` and are never written back. Re-pairing from Home Assistant
is intentionally not possible.

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

### Delivered in v2

- **MQTT bridge:** `telldus-mqtt` with Home Assistant MQTT discovery for
  devices and sensors — see [MQTT / Home Assistant Bridge](#mqtt--home-assistant-bridge)

### Not yet available

- **TelldusCenter/Qt GUI:** Not supported, headless only
- **Windows/macOS/FreeBSD:** Linux-only
- **Native packaging:** systemd service, APK/DEB packages
- **Multi-arch published images:** build locally for amd64/arm64 for now
- **Device pairing UI:** Use existing `tellstick.conf`
- **Scenes over MQTT:** `TELLSTICK_TYPE_SCENE` is not exposed as an HA entity (groups are, as switches)
- **Re-pairing over MQTT:** `tdLearn` is intentionally not exposed

### Project Documentation

- [PROJECT.md](.planning/PROJECT.md) - Full project context and decisions
- [ROADMAP.md](.planning/ROADMAP.md) - Phase-by-phase roadmap
- [MQTT-DESIGN.md](.planning/MQTT-DESIGN.md) - MQTT bridge design (milestone v2)
- [docs/REPOSITORY.md](docs/REPOSITORY.md) - Repository and docs folder organization
- [docs/verification-checklist.md](docs/verification-checklist.md) - Hardware verification

---

## License

See the COPYING file in the repository for license information.
