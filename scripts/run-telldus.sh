#!/bin/bash
#
# run-telldus.sh - Helper script to run Telldus Core daemon in Docker
# Phase 06: Containerized Daemon Runtime
#
# This script provides a convenient way to run the telldus daemon with
# proper USB passthrough and persistence configuration.
#
# PREREQUISITES:
#   - Docker daemon must be running
#   - Docker image 'telldus:latest' must be built (from Phase 5)
#   - TellStick Duo must be connected to USB
#   - Config file must exist at the path you specify
#
# USAGE:
#   1. Set CONFIG_PATH to point to your tellstick.conf
#   2. Run: CONFIG_PATH=/path/to/tellstick.conf ./scripts/run-telldus.sh
#   3. Verify: docker exec telldus tdtool --list
#
# EXAMPLE:
#   # With custom config path
#   CONFIG_PATH=/home/pi/tellstick.conf ./scripts/run-telldus.sh
#
#   # Or edit this file and change the fallback CONFIG_PATH
#
# VERIFICATION COMMANDS:
#   docker ps | grep telldus          # Check container is running
#   docker logs telldus --tail 20     # View recent logs
#   docker exec telldus lsusb | grep -i ftdi   # Verify USB access
#   docker exec telldus tdtool --list # List configured devices
#
# NOTE ABOUT --privileged (D-06-01):
#   The --privileged flag is REQUIRED for TellStick Duo USB access.
#   Without it, the container cannot open /dev/ttyUSB* devices.
#   This is the v1 pragmatic choice; future versions may use fine-grained
#   capabilities like --cap-add SYS_RAWIO with udev rules.
#
# NOTE ABOUT STATE PERSISTENCE (D-06-12):
#   The named volume 'telldus-state' preserves device states and learned
#   devices across container restarts. Without this, state is lost when
#   the container is removed.
#
# MQTT / HOME ASSISTANT BRIDGE (milestone v2):
#   Set MQTT_BROKER_HOST to run the telldus-mqtt bridge instead of the plain
#   daemon. Any other MQTT_* variable that is set gets forwarded into the
#   container as-is (see MQTT-DESIGN.md for the full list). MQTT_RAW_EVENTS=1
#   additionally publishes tdRegisterRawDeviceEvent frames to <prefix>/raw
#   (non-retained), for debugging devices/sensors Telldus doesn't recognize.
#   Example:
#     CONFIG_PATH=/etc/tellstick.conf MQTT_BROKER_HOST=mqtt.lan \
#       ./scripts/run-telldus.sh
#
# NOTE ABOUT DEVICE STATE (optimistic):
#   433 MHz transmission is fire-and-forget: there is no acknowledgement
#   from the physical device. The bridge's device/<id>/state topic reflects
#   the last command *sent* (tdLastSentCommand), not a confirmed reading.
#   A device toggled by its own physical remote will read wrong in MQTT/HA
#   unless that remote is itself configured as a receiving device in
#   tellstick.conf.
#

# CONFIGURATION
# CONFIG_PATH should point to your existing tellstick.conf on the host.
# Prefer passing it as an environment variable:
#   CONFIG_PATH=/path/to/tellstick.conf ./scripts/run-telldus.sh
CONFIG_PATH="${CONFIG_PATH:-/path/to/your/tellstick.conf}"

# Verify config file exists
if [ ! -f "$CONFIG_PATH" ]; then
    echo "ERROR: Config file not found at: $CONFIG_PATH"
    echo "Set CONFIG_PATH to your tellstick.conf path."
    echo "Example: CONFIG_PATH=/etc/tellstick.conf ./scripts/run-telldus.sh"
    exit 1
fi

MQTT_ENV_ARGS=()
COMMAND_ARGS=()
if [ -n "$MQTT_BROKER_HOST" ]; then
    echo "MQTT_BROKER_HOST is set: starting the telldus-mqtt bridge instead of the plain daemon."
    for var in MQTT_BROKER_HOST MQTT_BROKER_PORT MQTT_USERNAME MQTT_PASSWORD \
        MQTT_CLIENT_ID MQTT_TLS_CA MQTT_TOPIC_PREFIX MQTT_DISCOVERY_PREFIX \
        MQTT_QOS MQTT_LOG_LEVEL MQTT_RAW_EVENTS; do
        if [ -n "${!var}" ]; then
            MQTT_ENV_ARGS+=(-e "${var}=${!var}")
        fi
    done
    COMMAND_ARGS=(telldus-mqtt)
fi

echo "Starting Telldus daemon with config: $CONFIG_PATH"

# Run the container with all required options
docker run -d \
    --name telldus \
    --privileged \
    --restart unless-stopped \
    -v "${CONFIG_PATH}:/etc/tellstick.conf:ro" \
    -v telldus-state:/var/lib/telldus \
    "${MQTT_ENV_ARGS[@]}" \
    telldus:latest \
    "${COMMAND_ARGS[@]}"

# Check if container started successfully
if [ $? -eq 0 ]; then
    echo "Telldus daemon started successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Wait a few seconds for daemon initialization"
    echo "  2. Verify USB access: docker exec telldus lsusb | grep -i ftdi"
    echo "  3. List devices:        docker exec telldus tdtool --list"
    echo "  4. View logs:           docker logs telldus --tail 50"
    echo ""
    echo "To stop: docker stop telldus && docker rm telldus"
else
    echo "ERROR: Failed to start Telldus daemon"
    exit 1
fi
