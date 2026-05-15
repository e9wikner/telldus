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
#   1. Edit the CONFIG_PATH variable below to point to your tellstick.conf
#   2. Run: ./scripts/run-telldus.sh
#   3. Verify: docker exec telldus tdtool --list
#
# EXAMPLE:
#   # With custom config path
#   CONFIG_PATH=/home/pi/tellstick.conf ./scripts/run-telldus.sh
#
#   # Or edit this file and change the default CONFIG_PATH
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

# CONFIGURATION - CHANGE THIS PATH TO YOUR ACTUAL CONFIG FILE
# This should point to your existing tellstick.conf on the host
CONFIG_PATH="/path/to/your/tellstick.conf"

# Verify config file exists
if [ ! -f "$CONFIG_PATH" ]; then
    echo "ERROR: Config file not found at: $CONFIG_PATH"
    echo "Please edit this script and set CONFIG_PATH to your tellstick.conf"
    echo "Example: CONFIG_PATH=/etc/tellstick.conf"
    exit 1
fi

echo "Starting Telldus daemon with config: $CONFIG_PATH"

# Run the container with all required options
docker run -d \
    --name telldus \
    --privileged \
    --restart unless-stopped \
    -v "${CONFIG_PATH}:/etc/tellstick.conf:ro" \
    -v telldus-state:/var/lib/telldus \
    telldus:latest

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
