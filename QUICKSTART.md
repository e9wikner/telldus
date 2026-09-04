# Quickstart

Copy-paste commands only. For explanations and troubleshooting, see [README.md](README.md).

---

## Docker Quickstart

```bash
# Build image
./scripts/build-docker.sh --load

# Run with helper script
CONFIG_PATH=/path/to/your/tellstick.conf ./scripts/run-telldus.sh

# Or run manually
docker run -d \
  --name telldus \
  --privileged \
  --restart unless-stopped \
  -v /path/to/your/tellstick.conf:/etc/tellstick.conf:ro \
  -v telldus-state:/var/lib/telldus \
  telldus:latest

# Verify
docker exec telldus tdtool --list
docker exec telldus tdtool --on 1
docker exec telldus tdtool --off 1
```

### Docker Compose

```bash
# Edit docker-compose.yml to set your config path, then:
docker-compose up -d
docker-compose exec telldus tdtool --list
```

---

## MQTT / Home Assistant Bridge

```bash
# With the helper script — set MQTT_BROKER_HOST to switch it on
CONFIG_PATH=/path/to/your/tellstick.conf MQTT_BROKER_HOST=mqtt.lan \
  ./scripts/run-telldus.sh

# Or run manually
docker run -d \
  --name telldus \
  --privileged \
  --restart unless-stopped \
  -v /path/to/your/tellstick.conf:/etc/tellstick.conf:ro \
  -v telldus-state:/var/lib/telldus \
  -e MQTT_BROKER_HOST=mqtt.lan \
  -e MQTT_USERNAME=youruser \
  -e MQTT_PASSWORD=yourpass \
  telldus:latest telldus-mqtt

# Verify: devices/sensors publish under telldus/... and
# homeassistant/.../telldus/.../config — tdtool still works unchanged
docker exec telldus tdtool --list
mosquitto_sub -h mqtt.lan -t 'telldus/#' -v
```

See [README.md](README.md#mqtt--home-assistant-bridge) for the full
environment variable list and topic scheme.

---

## Native Build - Arch Linux

```bash
# Install dependencies
./scripts/install-arch-deps.sh

# Build
cmake --preset headless
cmake --build build/headless --parallel $(nproc)

# Run tests
ctest --test-dir build/headless -R cppunit

# Run daemon
sudo ./build/headless/service/telldusd

# Use tdtool (in another terminal)
./build/headless/tdtool/tdtool --list
./build/headless/tdtool/tdtool --on 1
./build/headless/tdtool/tdtool --off 1
```

---

## Native Build - Debian / Raspberry Pi

```bash
# Install dependencies
sudo ./scripts/install-debian-deps.sh

# Build
cmake --preset headless
cmake --build build/headless --parallel $(nproc)

# Run tests
ctest --test-dir build/headless -R cppunit

# Run daemon
sudo ./build/headless/service/telldusd

# Use tdtool
./build/headless/tdtool/tdtool --list
```
