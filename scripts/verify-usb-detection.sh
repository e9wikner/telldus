#!/bin/bash
# verify-usb-detection.sh
#
# Automated USB detection verification script for TellStick Duo.
# Phase 07: TellStick Duo Hardware Verification
#
# Usage: ./scripts/verify-usb-detection.sh [container_name]
# Default container name: telldus
#
# This script verifies:
#   - TellStick Duo USB detection (VID 0x1781, PID 0x0C31)
#   - Error paths when hardware is not connected
#
# Exit codes:
#   0 - USB detection verified successfully
#   1 - USB detection failed or error path verification failed
#
# Prerequisites:
#   - Docker container running with --privileged flag
#   - TellStick Duo connected to USB (for positive test)

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
echo "TellStick Duo USB Detection Verification"
echo "Container: $CONTAINER_NAME"
echo "Started: $(date)"
echo "========================================"
echo ""

# Function: verify_usb_detection
# Checks if TellStick Duo is detected via USB in the container
# Returns: 0 if detected, 1 if not detected
verify_usb_detection() {
    local container="$1"
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}FAIL${NC}: Container '$container' is not running"
        echo "       Run: ./scripts/run-telldus.sh"
        return 1
    fi
    
    # Check for TellStick Duo USB device (VID 0x1781, PID 0x0C31)
    local usb_output
    usb_output=$(docker exec "$container" lsusb 2>/dev/null | grep "1781:0c31" || true)
    
    if [ -n "$usb_output" ]; then
        echo -e "${GREEN}PASS${NC}: TellStick Duo USB detected"
        echo "       Device info: $usb_output"
        return 0
    else
        echo -e "${RED}FAIL${NC}: TellStick Duo not found in USB bus"
        echo "       Expected: VID 0x1781, PID 0x0C31"
        echo "       Run: docker exec $container lsusb"
        return 1
    fi
}

# Function: verify_error_path_no_usb
# Verifies error handling when TellStick is not connected (per D-07-11)
# Returns: 0 if error path verified, 1 if unexpected behavior
verify_error_path_no_usb() {
    local container="$1"
    
    # Check if USB is present first
    if docker exec "$container" lsusb 2>/dev/null | grep -q "1781:0c31"; then
        echo -e "${YELLOW}SKIP${NC}: TellStick is connected - cannot test error path"
        echo "       Disconnect TellStick to test error handling"
        return 0
    fi
    
    # Try tdtool --list without hardware connected
    local exit_code=0
    docker exec "$container" tdtool --list >/dev/null 2>&1 || exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo -e "${GREEN}PASS${NC}: Error path verified - graceful failure without hardware"
        echo "       Exit code: $exit_code (non-zero indicates error)"
        return 0
    else
        echo -e "${RED}FAIL${NC}: Unexpected success without hardware"
        echo "       Expected non-zero exit code when TellStick not connected"
        return 1
    fi
}

# Main verification flow
echo "Test 1: USB Device Detection"
echo "-----------------------------"
echo "Checking for TellStick Duo (VID 0x1781, PID 0x0C31)..."
if verify_usb_detection "$CONTAINER_NAME"; then
    ((PASS_COUNT++))
    USB_DETECTED=true
else
    ((FAIL_COUNT++))
    USB_DETECTED=false
fi
echo ""

echo "Test 2: Error Path Verification (No Hardware)"
echo "----------------------------------------------"
if [ "$USB_DETECTED" = false ]; then
    echo "TellStick not detected - verifying error path behavior..."
    if verify_error_path_no_usb "$CONTAINER_NAME"; then
        ((PASS_COUNT++))
    else
        ((FAIL_COUNT++))
    fi
else
    echo -e "${YELLOW}SKIP${NC}: TellStick detected - error path test not applicable"
    echo "       To test error paths, disconnect TellStick and re-run"
fi
echo ""

# Summary
echo "========================================"
echo "Verification Summary"
echo "========================================"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    if [ "$USB_DETECTED" = true ]; then
        echo "TellStick Duo is properly detected and ready for use."
        echo ""
        echo "Next steps:"
        echo "  - List devices: docker exec $CONTAINER_NAME tdtool --list"
        echo "  - Run full hardware test: ./scripts/verify-tellstick-hardware.sh"
    else
        echo "Error path verification complete."
        echo "Connect TellStick Duo to test full functionality."
    fi
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check USB cable connection to TellStick Duo"
    echo "  2. Verify container is running: docker ps | grep $CONTAINER_NAME"
    echo "  3. Ensure --privileged flag was used when starting container"
    echo "  4. Try different USB port on host"
    echo "  5. Check host USB detection: lsusb | grep 1781:0c31"
    echo ""
    echo "For more help, see: docs/hardware-verification.md"
    exit 1
fi
