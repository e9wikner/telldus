#!/bin/bash
set -euo pipefail

IMAGE="telldus:latest"
TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

test_sample_config_exists() {
	echo -n "Test: sample config exists as fallback ... "
	if docker run --rm --entrypoint cat "$IMAGE" /etc/tellstick.conf 2>/dev/null | grep -q 'user = "nobody"'; then
		echo "PASS"
		((PASS_COUNT++))
	else
		echo "FAIL"
		((FAIL_COUNT++))
	fi
}

test_bind_mount() {
	echo -n "Test: config bind mount overwrites sample ... "
	cat > "$TESTDIR/test.conf" <<EOF
user = "test"
group = "plugdev"
EOF
	if docker run --rm --entrypoint cat -v "$TESTDIR/test.conf:/etc/tellstick.conf:ro" "$IMAGE" /etc/tellstick.conf 2>/dev/null | grep -q 'user = "test"'; then
		echo "PASS"
		((PASS_COUNT++))
	else
		echo "FAIL"
		((FAIL_COUNT++))
	fi
}

test_default_daemon() {
	echo -n "Test: default CMD is telldusd --nodaemon ... "
	if docker inspect --format='{{.Config.Cmd}}' "$IMAGE" 2>/dev/null | grep -q 'telldusd --nodaemon'; then
		echo "PASS"
		((PASS_COUNT++))
	else
		echo "FAIL"
		((FAIL_COUNT++))
	fi
}

test_oneshot_tdtool() {
	echo -n "Test: one-shot tdtool dispatch works ... "
	if docker run --rm "$IMAGE" tdtool --help 2>/dev/null | grep -q 'tdtool'; then
		echo "PASS"
		((PASS_COUNT++))
	else
		echo "FAIL"
		((FAIL_COUNT++))
	fi
}

test_no_build_tools() {
	echo -n "Test: no build tools in final image ... "
	if docker run --rm --entrypoint sh "$IMAGE" -c "which gcc || which cmake || which g++" 2>/dev/null | grep -q .; then
		echo "FAIL"
		((FAIL_COUNT++))
	elif [ "${PIPESTATUS[0]}" -ne 0 ]; then
		# which returned non-zero (no build tools found) — this is what we want
		echo "PASS"
		((PASS_COUNT++))
	else
		# which succeeded but output was empty (unlikely)
		echo "PASS"
		((PASS_COUNT++))
	fi
}

# Run all tests
test_sample_config_exists
test_bind_mount
test_default_daemon
test_oneshot_tdtool
test_no_build_tools

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo ""
echo "========================================"
echo "${PASS_COUNT}/${TOTAL} tests passed"
echo "========================================"

if [ "$FAIL_COUNT" -gt 0 ]; then
	exit 1
fi
