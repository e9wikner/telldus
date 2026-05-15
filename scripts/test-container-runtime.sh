#!/bin/bash
# test-container-runtime.sh
#
# Test script for verifying tdtool communication with the containerized daemon.
# Uses docker exec pattern as the primary communication method (D-06-04).
#
# Usage: ./scripts/test-container-runtime.sh [container_name]
# Default container name: telldus
#
# Tests:
#   - Container is running
#   - tdtool --help works via docker exec
#   - tdtool --list works via docker exec  
#   - USB device access (FTDI/TellStick)
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -e

CONTAINER_NAME="${1:-telldus}"
PASS_COUNT=0
FAIL_COUNT=0

# Color codes for output (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

echo "========================================"
echo "Telldus Container Runtime Test Script"
echo "Container: $CONTAINER_NAME"
echo "Started: $(date)"
echo "========================================"
echo ""

# Test 1: Verify container is running
echo "Test 1: Container running check"
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${GREEN}PASS${NC}: Container '$CONTAINER_NAME' is running"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC}: Container '$CONTAINER_NAME' is not running"
    echo "       Run: docker ps | grep $CONTAINER_NAME"
    ((FAIL_COUNT++))
    # Skip remaining tests if container not running
    echo ""
    echo "========================================"
    echo "Container not running - aborting tests"
    echo "========================================"
    exit 1
fi
echo ""

# Test 2: Verify tdtool --help works via docker exec
echo "Test 2: tdtool --help via docker exec"
if docker exec "$CONTAINER_NAME" tdtool --help >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}: tdtool --help executed successfully"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC}: tdtool --help failed"
    echo "       Command: docker exec $CONTAINER_NAME tdtool --help"
    ((FAIL_COUNT++))
fi
echo ""

# Test 3: Verify tdtool --list works via docker exec
echo "Test 3: tdtool --list via docker exec"
if docker exec "$CONTAINER_NAME" tdtool --list >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}: tdtool --list executed successfully"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC}: tdtool --list failed"
    echo "       Command: docker exec $CONTAINER_NAME tdtool --list"
    echo "       Note: This may fail if the daemon hasn't finished starting"
    ((FAIL_COUNT++))
fi
echo ""

# Test 4: Verify USB device access (FTDI/TellStick)
echo "Test 4: USB device access (FTDI/TellStick)"
if docker exec "$CONTAINER_NAME" lsusb 2>/dev/null | grep -qi ftdi; then
    echo -e "${GREEN}PASS${NC}: FTDI USB device found"
    echo "       Device info:"
    docker exec "$CONTAINER_NAME" lsusb | grep -i ftdi | head -1 | sed 's/^/       /'
    ((PASS_COUNT++))
else
    echo -e "${YELLOW}WARN${NC}: No FTDI USB device found"
    echo "       This is expected if TellStick is not physically connected."
    echo "       Command: docker exec $CONTAINER_NAME lsusb | grep -i ftdi"
    # Don't count as fail - hardware may not be connected
fi
echo ""

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  - View devices: docker exec $CONTAINER_NAME tdtool --list"
    echo "  - View logs: docker logs $CONTAINER_NAME --tail 20"
    echo "  - Control devices: docker exec $CONTAINER_NAME tdtool --on <device_id>"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check container status: docker ps | grep $CONTAINER_NAME"
    echo "  2. Check logs: docker logs $CONTAINER_NAME --tail 50"
    echo "  3. Verify daemon started: docker exec $CONTAINER_NAME pgrep telldusd"
    echo "  4. Check USB access: docker exec $CONTAINER_NAME lsusb"
    exit 1
fi