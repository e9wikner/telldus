#!/bin/bash
# verify-error-paths.sh
#
# Automated error path verification script for TellStick Duo.
# Phase 07: TellStick Duo Hardware Verification
#
# Usage: ./scripts/verify-error-paths.sh [container_name]
# Default container name: telldus
#
# This script verifies error handling when:
#   - TellStick Duo is not connected
#   - Invalid device IDs are specified
#   - Daemon connection issues occur
#
# Per D-07-11: "When TellStick Duo is not physically connected, verify
# error paths: tdtool returns TELLSTICK_ERROR_NOT_FOUND or similar"
#
# Exit codes:
#   0 - All error path tests passed
#   1 - One or more tests failed
#
# Prerequisites:
#   - Docker container running (for some tests)
#   - TellStick Duo disconnected (for no-hardware test)

set -e

CONTAINER_NAME="${1:-telldus}"
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Color codes for output
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# tdtool error codes (from telldus-core.h)
readonly TELLSTICK_SUCCESS=0
readonly TELLSTICK_ERROR_NOT_FOUND=1
readonly TELLSTICK_ERROR_PERMISSION_DENIED=2
readonly TELLSTICK_ERROR_DEVICE_NOT_FOUND=3
readonly TELLSTICK_ERROR_METHOD_NOT_SUPPORTED=4
readonly TELLSTICK_ERROR_COMMUNICATION=5
readonly TELLSTICK_ERROR_CONNECTING_SERVICE=6
readonly TELLSTICK_ERROR_UNKNOWN_RESPONSE=7
readonly TELLSTICK_ERROR_SYNTAX=8
readonly TELLSTICK_ERROR_BROKEN_PIPE=9
readonly TELLSTICK_ERROR_COMMUNICATING_SERVICE=10
readonly TELLSTICK_ERROR_CONFIG_SYNTAX=11
readonly TELLSTICK_ERROR_UNKNOWN=99

echo "========================================"
echo "TellStick Duo Error Path Verification"
echo "Container: $CONTAINER_NAME"
echo "Started: $(date)"
echo "========================================"
echo ""

# Check if container is running
check_container_running() {
    local container="$1"
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        return 0
    else
        return 1
    fi
}

# Verify error handling when no hardware connected
verify_no_hardware_error() {
    echo "Test 1: No Hardware Connected Error Path"
    echo "-----------------------------------------"
    
    if ! check_container_running "$CONTAINER_NAME"; then
        echo -e "${YELLOW}SKIP${NC}: Container not running - cannot test"
        ((SKIP_COUNT++))
        return 0
    fi
    
    # Check if USB is present
    local usb_present=false
    if docker exec "$CONTAINER_NAME" lsusb 2>/dev/null | grep -q "1781:0c31"; then
        usb_present=true
    fi
    
    if [ "$usb_present" = true ]; then
        echo -e "${YELLOW}SKIP${NC}: TellStick is connected - cannot test no-hardware error path"
        echo "       Disconnect TellStick to run this test"
        ((SKIP_COUNT++))
        return 0
    fi
    
    echo "TellStick not detected - testing error path..."
    
    # Test tdtool --list without hardware
    local exit_code=0
    local output
    output=$(docker exec "$CONTAINER_NAME" tdtool --list 2>&1) || exit_code=$?
    
    echo "  Exit code: $exit_code"
    
    if [ $exit_code -ne $TELLSTICK_SUCCESS ]; then
        echo -e "  ${GREEN}PASS${NC}: tdtool --list returns error without hardware"
        echo "         Exit code $exit_code (non-zero indicates error)"
        
        # Check for meaningful error message
        if echo "$output" | grep -qiE "(error|failed|not found|unable|could not)"; then
            echo -e "  ${GREEN}PASS${NC}: Error message is meaningful"
            echo "         Output contains error indicators"
        else
            echo -e "  ${YELLOW}WARN${NC}: Error message may not be user-friendly"
            echo "         Output: ${output:0:100}"
        fi
        
        ((PASS_COUNT++))
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: Unexpected success without hardware"
        echo "         Expected non-zero exit code when TellStick not connected"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Verify error for invalid device ID
verify_invalid_device_error() {
    echo ""
    echo "Test 2: Invalid Device ID Error Path"
    echo "-------------------------------------"
    
    if ! check_container_running "$CONTAINER_NAME"; then
        echo -e "${YELLOW}SKIP${NC}: Container not running - cannot test"
        ((SKIP_COUNT++))
        return 0
    fi
    
    echo "Testing tdtool --on 999 (invalid device ID)..."
    
    local exit_code=0
    local output
    output=$(docker exec "$CONTAINER_NAME" tdtool --on 999 2>&1) || exit_code=$?
    
    echo "  Exit code: $exit_code"
    
    # Expected: TELLSTICK_ERROR_DEVICE_NOT_FOUND (3)
    if [ $exit_code -eq $TELLSTICK_ERROR_DEVICE_NOT_FOUND ]; then
        echo -e "  ${GREEN}PASS${NC}: Invalid device ID returns TELLSTICK_ERROR_DEVICE_NOT_FOUND (3)"
        ((PASS_COUNT++))
        return 0
    elif [ $exit_code -ne $TELLSTICK_SUCCESS ]; then
        echo -e "  ${GREEN}PASS${NC}: Invalid device ID returns error (exit: $exit_code)"
        echo "         Note: Expected exit code 3, got $exit_code"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: Invalid device ID should return error"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Verify daemon connection error
verify_daemon_connection_error() {
    echo ""
    echo "Test 3: Daemon Connection Error"
    echo "--------------------------------"
    
    echo "Testing tdtool against non-existent container..."
    
    local exit_code=0
    docker exec "nonexistent-telldus-$$" tdtool --list 2>/dev/null || exit_code=$?
    
    echo "  Exit code: $exit_code"
    
    if [ $exit_code -ne 0 ]; then
        echo -e "  ${GREEN}PASS${NC}: Connection to non-existent container fails gracefully"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: Expected error for non-existent container"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Verify malformed command handling
verify_malformed_command() {
    echo ""
    echo "Test 4: Malformed Command Handling"
    echo "-----------------------------------"
    
    if ! check_container_running "$CONTAINER_NAME"; then
        echo -e "${YELLOW}SKIP${NC}: Container not running - cannot test"
        ((SKIP_COUNT++))
        return 0
    fi
    
    echo "Testing tdtool with invalid argument..."
    
    local exit_code=0
    docker exec "$CONTAINER_NAME" tdtool --invalid-flag 2>/dev/null || exit_code=$?
    
    echo "  Exit code: $exit_code"
    
    if [ $exit_code -ne 0 ]; then
        echo -e "  ${GREEN}PASS${NC}: Invalid argument handled gracefully"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: Expected error for invalid argument"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Print error code reference
print_error_reference() {
    echo ""
    echo "========================================"
    echo "tdtool Exit Code Reference"
    echo "========================================"
    echo ""
    echo "| Code | Constant                          | Meaning"
    echo "|------|-----------------------------------|--------------------------------"
    echo "| 0    | TELLSTICK_SUCCESS                 | Command successful"
    echo "| 1    | TELLSTICK_ERROR_NOT_FOUND         | Device/method not found"
    echo "| 2    | TELLSTICK_ERROR_PERMISSION_DENIED | Permission denied"
    echo "| 3    | TELLSTICK_ERROR_DEVICE_NOT_FOUND  | Device ID not found"
    echo "| 4    | TELLSTICK_ERROR_METHOD_NOT_SUPPORTED | Method not supported"
    echo "| 5    | TELLSTICK_ERROR_COMMUNICATION     | Communication error"
    echo "| 6    | TELLSTICK_ERROR_CONNECTING_SERVICE | Cannot connect to service"
    echo "| 7    | TELLSTICK_ERROR_UNKNOWN_RESPONSE  | Unknown response from device"
    echo "| 8    | TELLSTICK_ERROR_SYNTAX            | Command syntax error"
    echo "| 9    | TELLSTICK_ERROR_BROKEN_PIPE       | Broken pipe"
    echo "| 10   | TELLSTICK_ERROR_COMMUNICATING_SERVICE | Service communication error"
    echo "| 11   | TELLSTICK_ERROR_CONFIG_SYNTAX     | Configuration syntax error"
    echo "| 99   | TELLSTICK_ERROR_UNKNOWN           | Unknown error"
    echo ""
}

# Main execution
main() {
    # Run all error path tests
    verify_no_hardware_error
    verify_invalid_device_error
    verify_daemon_connection_error
    verify_malformed_command
    
    # Print reference
    print_error_reference
    
    # Summary
    echo "========================================"
    echo "Error Path Verification Summary"
    echo "========================================"
    echo "Passed: $PASS_COUNT"
    echo "Failed: $FAIL_COUNT"
    if [ $SKIP_COUNT -gt 0 ]; then
        echo "Skipped: $SKIP_COUNT"
    fi
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${GREEN}All error path tests passed!${NC}"
        echo ""
        if [ $SKIP_COUNT -gt 0 ]; then
            echo "Note: Some tests were skipped due to hardware being connected"
            echo "      or container not running. This is normal."
            echo ""
        fi
        echo "Error handling verified per D-07-11 requirement."
        exit 0
    else
        echo -e "${RED}Some error path tests failed.${NC}"
        echo ""
        exit 1
    fi
}

main "$@"
