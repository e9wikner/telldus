#!/bin/bash
set -euo pipefail

# Config compatibility smoke test
# Validates config parsing, path overrides, and auto-reload

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELLDUS_CORE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${TELLDUS_CORE_DIR}/build/headless"
DAEMON="${BUILD_DIR}/service/telldusd"
TDTOOL="${BUILD_DIR}/tdtool/tdtool"
SAMPLE_CONF="${SCRIPT_DIR}/sample-tellstick.conf"

if [ ! -x "${DAEMON}" ]; then
	echo "ERROR: telldusd not found at ${DAEMON}"
	exit 1
fi

if [ ! -x "${TDTOOL}" ]; then
	echo "ERROR: tdtool not found at ${TDTOOL}"
	exit 1
fi

if [ ! -f "${SAMPLE_CONF}" ]; then
	echo "ERROR: sample config not found at ${SAMPLE_CONF}"
	exit 1
fi

# Check for existing daemon socket
if [ -S /tmp/TelldusClient ]; then
	echo "WARNING: /tmp/TelldusClient already exists. Another telldusd may be running."
	echo "Stop the other daemon before running this test."
	exit 1
fi

TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT

cp "${SAMPLE_CONF}" "${TMPDIR}/tellstick.conf"

export TELLDUS_CONFIG_FILE="${TMPDIR}/tellstick.conf"
export TELLDUS_STATE_DIR="${TMPDIR}"
export LD_LIBRARY_PATH="${BUILD_DIR}/client:${LD_LIBRARY_PATH:-}"

echo "=== Starting telldusd ==="
"${DAEMON}" --nodaemon &
DAEMON_PID=$!
trap "kill ${DAEMON_PID} 2>/dev/null || true; rm -rf ${TMPDIR}" EXIT

sleep 2

echo "=== Listing devices (initial) ==="
OUTPUT=$(${TDTOOL} --list-devices)  # tdtool --list-devices
echo "${OUTPUT}"

# Verify initial 3 devices
for name in "Living room lamp" "Bedroom dimmer" "Outdoor switch"; do
	if ! echo "${OUTPUT}" | grep -qF "${name}"; then
		echo "FAIL: Device '${name}' not found in initial output"
		exit 1
	fi
	done
echo "PASS: All 3 initial devices found"

echo "=== Adding new device to config ==="
cat >> "${TMPDIR}/tellstick.conf" <<'EOF'

device {
	id = 4
	name = "New reload test device"
	protocol = "arctech"
	model = "codeswitch"
	parameters {
		house = "C"
		unit = "3"
	}
}
EOF

# Wait for debounce + reload (watcher sleeps 1s, then signals)
echo "=== Waiting for auto-reload (3s) ==="
sleep 3

echo "=== Listing devices (after reload) ==="
OUTPUT=$(${TDTOOL} --list-devices)  # tdtool --list-devices
echo "${OUTPUT}"

# Verify new device appeared
if ! echo "${OUTPUT}" | grep -qF "New reload test device"; then
	echo "FAIL: New device not found after reload"
	exit 1
fi
echo "PASS: New device found after auto-reload"

# Verify all 4 devices are present
for name in "Living room lamp" "Bedroom dimmer" "Outdoor switch" "New reload test device"; do
	if ! echo "${OUTPUT}" | grep -qF "${name}"; then
		echo "FAIL: Device '${name}' missing after reload"
		exit 1
	fi
done
echo "PASS: All 4 devices present after reload"

echo ""
echo "=== ALL TESTS PASSED ==="
exit 0
