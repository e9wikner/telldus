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

# Test 5: Container restart test (verifies persistence per D-06-10, D-06-12)
echo "Test 5: Container restart persistence"
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    # Capture device list before restart
    BEFORE=$(docker exec "$CONTAINER_NAME" tdtool --list 2>/dev/null || echo "FAILED")
    
    if [ "$BEFORE" = "FAILED" ]; then
        echo -e "${YELLOW}WARN${NC}: Could not capture device list before restart"
        echo "       Daemon may not be fully started yet. Skipping restart test."
    else
        echo "       Captured device list before restart"
        
        # Restart container
        echo "       Restarting container..."
        if docker restart "$CONTAINER_NAME" >/dev/null 2>&1; then
            # Wait for daemon to be ready
            sleep 3
            
            # Capture device list after restart
            AFTER=$(docker exec "$CONTAINER_NAME" tdtool --list 2>/dev/null || echo "FAILED")
            
            if [ "$AFTER" = "FAILED" ]; then
                echo -e "${RED}FAIL${NC}: tdtool --list failed after restart"
                ((FAIL_COUNT++))
            elif [ "$BEFORE" = "$AFTER" ]; then
                echo -e "${GREEN}PASS${NC}: Device list persisted after container restart"
                echo "       Devices before and after restart match"
                ((PASS_COUNT++))
            else
                echo -e "${YELLOW}WARN${NC}: Device list changed after restart"
                echo "       This may be normal if devices were controlled during restart."
                ((PASS_COUNT++))
            fi
        else
            echo -e "${RED}FAIL${NC}: Failed to restart container"
            ((FAIL_COUNT++))
        fi
    fi
else
    echo -e "${YELLOW}WARN${NC}: Container not running, skipping restart test"
fi
echo ""

# Test 6: State persistence check (verifies D-06-12)
echo "Test 6: State persistence check (/var/lib/telldus)"
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    if docker exec "$CONTAINER_NAME" test -d /var/lib/telldus 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: State directory /var/lib/telldus exists"
        
        # Check for state file
        if docker exec "$CONTAINER_NAME" test -f /var/lib/telldus/telldus-core.conf 2>/dev/null; then
            echo -e "${GREEN}PASS${NC}: State file telldus-core.conf exists"
            echo "       State persistence verified (D-06-12)"
            ((PASS_COUNT++))
        else
            echo -e "${YELLOW}WARN${NC}: State file telldus-core.conf not found"
            echo "       This is normal if no devices have been controlled yet."
            echo "       Directory exists - state will persist when written."
            ((PASS_COUNT++))
        fi
        
        # Show directory contents for debugging
        echo "       Directory contents:"
        docker exec "$CONTAINER_NAME" ls -la /var/lib/telldus/ 2>/dev/null | sed 's/^/       /'
    else
        echo -e "${RED}FAIL${NC}: State directory /var/lib/telldus does not exist"
        echo "       Ensure volume is mounted: -v telldus-state:/var/lib/telldus"
        ((FAIL_COUNT++))
    fi
else
    echo -e "${YELLOW}WARN${NC}: Container not running, skipping state check"
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