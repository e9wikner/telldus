#!/bin/bash
# verify-tellstick-hardware.sh
#
# Main hardware verification script for TellStick Duo.
# Phase 07: TellStick Duo Hardware Verification
#
# Usage: ./scripts/verify-tellstick-hardware.sh [options] [container_name] [device_id]
#
# Options:
#   --error-only    Run only error path tests (no hardware required)
#   --summary       Print condensed results suitable for checklist
#   --verbose       Print detailed output including command traces
#   --help          Show this help message
#
# Arguments:
#   container_name  Docker container name (default: telldus)
#   device_id       Device ID to test (default: 1)
#
# This script performs hybrid verification:
#   - Automated tests: USB detection, device listing, command transmission
#   - Manual verification: Physical observation of device response
#
# Exit codes:
#   0 - All automated tests passed
#   1 - One or more tests failed
#
# Prerequisites:
#   - Docker container running with TellStick Duo connected
#   - tellstick.conf configured with at least one device
#
# See also:
#   - docs/verification-checklist.md - Step-by-step manual verification
#   - docs/hardware-verification.md - Complete verification guide

set -e

# Default values
CONTAINER_NAME="telldus"
DEVICE_ID="1"
ERROR_ONLY_MODE=false
SUMMARY_MODE=false
VERBOSE_MODE=false

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Parse arguments
parse_arguments() {
    local positional=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --error-only)
                ERROR_ONLY_MODE=true
                shift
                ;;
            --summary)
                SUMMARY_MODE=true
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            -*)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done
    
    # Set positional arguments
    if [ ${#positional[@]} -ge 1 ]; then
        CONTAINER_NAME="${positional[0]}"
    fi
    if [ ${#positional[@]} -ge 2 ] && [ "$ERROR_ONLY_MODE" = false ]; then
        DEVICE_ID="${positional[1]}"
    fi
}

# Show help
show_help() {
    cat << 'EOF'
TellStick Duo Hardware Verification Script

USAGE:
    ./scripts/verify-tellstick-hardware.sh [options] [container_name] [device_id]

OPTIONS:
    --error-only    Run only error path tests (no hardware required)
    --summary       Print condensed results suitable for checklist
    --verbose       Print detailed output including command traces
    --help          Show this help message

ARGUMENTS:
    container_name  Docker container name (default: telldus)
    device_id       Device ID to test (default: 1)

EXAMPLES:
    # Standard verification (with hardware)
    ./scripts/verify-tellstick-hardware.sh

    # Test specific device
    ./scripts/verify-tellstick-hardware.sh telldus 2

    # Error-only mode (CI/testing without hardware)
    ./scripts/verify-tellstick-hardware.sh --error-only

    # Summary output for checklist
    ./scripts/verify-tellstick-hardware.sh --summary

EXIT CODES:
    0 - All tests passed
    1 - One or more tests failed

For complete verification procedures, see:
    - docs/verification-checklist.md
    - docs/hardware-verification.md
EOF
}

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

# Verbose logging
log_verbose() {
    if [ "$VERBOSE_MODE" = true ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $*"
    fi
}

# Check if container is running
check_container_running() {
    local container="$1"
    log_verbose "Checking if container '$container' is running"
    
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        log_verbose "Container '$container' is running"
        return 0
    else
        echo -e "${RED}ERROR${NC}: Container '$container' is not running"
        echo "       Run: ./scripts/run-telldus.sh"
        return 1
    fi
}

# Verify USB detection (from 07-01)
verify_usb_detection() {
    local container="$1"
    
    echo "[Test 1] USB Detection"
    log_verbose "Checking for TellStick Duo (VID 0x1781, PID 0x0C31)"
    
    if ! check_container_running "$container"; then
        echo -e "  ${RED}FAIL${NC}: Container not running"
        return 1
    fi
    
    local usb_output
    usb_output=$(docker exec "$container" lsusb 2>/dev/null | grep "1781:0c31" || true)
    
    if [ -n "$usb_output" ]; then
        echo -e "  ${GREEN}PASS${NC}: TellStick Duo USB detected"
        log_verbose "Device info: $usb_output"
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: TellStick Duo not found"
        echo "         Check USB cable and --privileged flag"
        return 1
    fi
}

# Verify device listing (DUO-03)
verify_device_listing() {
    local container="$1"
    
    echo "[Test 2] Device Listing"
    log_verbose "Running: docker exec $container tdtool --list"
    
    local output
    local exit_code=0
    output=$(docker exec "$container" tdtool --list 2>&1) || exit_code=$?
    
    log_verbose "Exit code: $exit_code"
    log_verbose "Output: $output"
    
    if [ $exit_code -eq 0 ]; then
        local device_count
        device_count=$(echo "$output" | grep -c "^Number of devices:" || true)
        if [ "$device_count" -gt 0 ]; then
            echo -e "  ${GREEN}PASS${NC}: Device listing successful"
            echo "         $output" | head -3 | sed 's/^/         /'
            return 0
        else
            echo -e "  ${YELLOW}WARN${NC}: Device list returned but format unexpected"
            return 0
        fi
    else
        echo -e "  ${RED}FAIL${NC}: Device listing failed (exit code: $exit_code)"
        echo "         $output" | head -2 | sed 's/^/         /'
        return 1
    fi
}

# Verify on/off commands (DUO-04)
verify_on_off_commands() {
    local container="$1"
    local device_id="$2"
    
    echo "[Test 3] On/Off Commands (Device ID: $device_id)"
    log_verbose "Testing on/off commands for device $device_id"
    
    local on_exit=0
    local off_exit=0
    
    # Test ON command
    log_verbose "Running: docker exec $container tdtool --on $device_id"
    local on_output
    on_output=$(docker exec "$container" tdtool --on "$device_id" 2>&1) || on_exit=$?
    log_verbose "ON command exit code: $on_exit"
    
    if [ $on_exit -eq 0 ]; then
        echo -e "  ${GREEN}PASS${NC}: ON command transmitted"
    else
        echo -e "  ${RED}FAIL${NC}: ON command failed (exit: $on_exit)"
        echo "         $on_output" | sed 's/^/         /'
    fi
    
    # Wait for RF transmission
    log_verbose "Waiting 2 seconds for RF transmission..."
    sleep 2
    
    # Test OFF command
    log_verbose "Running: docker exec $container tdtool --off $device_id"
    local off_output
    off_output=$(docker exec "$container" tdtool --off "$device_id" 2>&1) || off_exit=$?
    log_verbose "OFF command exit code: $off_exit"
    
    if [ $off_exit -eq 0 ]; then
        echo -e "  ${GREEN}PASS${NC}: OFF command transmitted"
    else
        echo -e "  ${RED}FAIL${NC}: OFF command failed (exit: $off_exit)"
        echo "         $off_output" | sed 's/^/         /'
    fi
    
    # Warning about one-way communication
    if [ $on_exit -eq 0 ] && [ $off_exit -eq 0 ]; then
        echo ""
        echo -e "  ${YELLOW}⚠ IMPORTANT${NC}: 433 MHz is one-way communication"
        echo "         Exit code 0 means 'command transmitted', NOT 'device acknowledged'"
        echo "         Physically verify the device actually responded"
        return 0
    else
        return 1
    fi
}

# Error path: test tdtool without daemon
verify_tdtool_without_daemon() {
    echo "[Error Test 1] Connection Error (No Daemon)"
    log_verbose "Testing tdtool against non-existent container"
    
    local exit_code=0
    docker exec "nonexistent-telldus-$$" tdtool --list 2>/dev/null || exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo -e "  ${GREEN}PASS${NC}: Connection error handled gracefully (exit: $exit_code)"
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: Expected error for non-existent container"
        return 1
    fi
}

# Error path: test invalid device ID
verify_invalid_device_id() {
    local container="$1"
    
    echo "[Error Test 2] Invalid Device ID"
    log_verbose "Testing tdtool --on 999 (invalid device)"
    
    if ! check_container_running "$container" 2>/dev/null; then
        echo -e "  ${YELLOW}SKIP${NC}: Container not running - cannot test"
        ((SKIP_COUNT++))
        return 0
    fi
    
    local exit_code=0
    docker exec "$container" tdtool --on 999 2>/dev/null || exit_code=$?
    log_verbose "Exit code for invalid device: $exit_code"
    
    # Exit code 3 = TELLSTICK_ERROR_DEVICE_NOT_FOUND
    if [ $exit_code -eq 3 ]; then
        echo -e "  ${GREEN}PASS${NC}: Invalid device returns correct error (exit: 3)"
        echo "         TELLSTICK_ERROR_DEVICE_NOT_FOUND"
        return 0
    elif [ $exit_code -ne 0 ]; then
        echo -e "  ${GREEN}PASS${NC}: Invalid device returns error (exit: $exit_code)"
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: Expected error for invalid device ID"
        return 1
    fi
}

# Run error mode tests only
run_error_mode_tests() {
    echo "========================================"
    echo "Error Path Verification (No Hardware)"
    echo "Started: $(date)"
    echo "========================================"
    echo ""
    
    verify_tdtool_without_daemon && ((PASS_COUNT++)) || ((FAIL_COUNT++))
    echo ""
    
    verify_invalid_device_id "$CONTAINER_NAME" && ((PASS_COUNT++)) || ((FAIL_COUNT++))
    echo ""
}

# Print summary output
print_summary() {
    echo ""
    echo "========================================"
    echo "Verification Summary"
    echo "========================================"
    printf "%-30s %s\n" "Test" "Result"
    printf "%-30s %s\n" "----" "------"
}

# Main execution
main() {
    parse_arguments "$@"
    
    if [ "$ERROR_ONLY_MODE" = true ]; then
        run_error_mode_tests
    else
        echo "========================================"
        echo "TellStick Duo Hardware Verification"
        echo "Container: $CONTAINER_NAME"
        echo "Device ID: $DEVICE_ID"
        echo "Started: $(date)"
        echo "========================================"
        echo ""
        
        # Run automated tests
        verify_usb_detection "$CONTAINER_NAME" && ((PASS_COUNT++)) || ((FAIL_COUNT++))
        echo ""
        
        verify_device_listing "$CONTAINER_NAME" && ((PASS_COUNT++)) || ((FAIL_COUNT++))
        echo ""
        
        verify_on_off_commands "$CONTAINER_NAME" "$DEVICE_ID" && ((PASS_COUNT++)) || ((FAIL_COUNT++))
        echo ""
        
        # Manual verification section
        echo "========================================"
        echo "Manual Verification Required"
        echo "========================================"
        echo ""
        echo "1. Observe the physical device during the ON command"
        echo "2. Confirm the device turned ON (light, movement, sound, etc.)"
        echo "3. Observe the physical device during the OFF command"
        echo "4. Confirm the device turned OFF"
        echo ""
        echo "If the device did not respond:"
        echo "  - Check device power/batteries"
        echo "  - Verify device is paired with TellStick"
        echo "  - Check for RF interference"
        echo "  - Try the command again"
        echo ""
    fi
    
    # Summary output
    if [ "$SUMMARY_MODE" = true ]; then
        print_summary
    else
        echo "========================================"
        echo "Test Summary"
        echo "========================================"
    fi
    
    echo "Passed: $PASS_COUNT"
    echo "Failed: $FAIL_COUNT"
    if [ $SKIP_COUNT -gt 0 ]; then
        echo "Skipped: $SKIP_COUNT"
    fi
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "${GREEN}All automated tests passed!${NC}"
        echo ""
        if [ "$ERROR_ONLY_MODE" = false ]; then
            echo "Remember: Physical verification of device response is required."
            echo ""
            echo "Next steps:"
            echo "  - Complete manual verification checklist: docs/verification-checklist.md"
            echo "  - Control devices: docker exec $CONTAINER_NAME tdtool --on <id>"
            echo "  - View logs: docker logs $CONTAINER_NAME --tail 20"
        fi
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check container status: docker ps | grep $CONTAINER_NAME"
        echo "  2. Check logs: docker logs $CONTAINER_NAME --tail 50"
        echo "  3. Verify USB: docker exec $CONTAINER_NAME lsusb | grep 1781:0c31"
        echo "  4. Check device ID exists: docker exec $CONTAINER_NAME tdtool --list"
        echo ""
        exit 1
    fi
}

main "$@"
