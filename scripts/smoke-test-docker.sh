#!/bin/bash
set -euo pipefail

IMAGE="telldus:latest"
TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

test_sample_config_exists() {
	echo -n "Test: sample config exists as fallback ... "
	docker run --rm --entrypoint cat "$IMAGE" /etc/tellstick.conf > "$TESTDIR/sample.conf" 2>/dev/null || true
	if grep -q 'user = "nobody"' "$TESTDIR/sample.conf" 2>/dev/null; then
		echo "PASS"
		((PASS_COUNT++)) || true
	else
		echo "FAIL"
		((FAIL_COUNT++)) || true
	fi
}

test_bind_mount() {
	echo -n "Test: config bind mount overwrites sample ... "
	cat > "$TESTDIR/test.conf" <<EOF
user = "test"
group = "plugdev"
EOF
	docker run --rm --entrypoint cat -v "$TESTDIR/test.conf:/etc/tellstick.conf:ro" "$IMAGE" /etc/tellstick.conf > "$TESTDIR/mounted.conf" 2>/dev/null || true
	if grep -q 'user = "test"' "$TESTDIR/mounted.conf" 2>/dev/null; then
		echo "PASS"
		((PASS_COUNT++)) || true
	else
		echo "FAIL"
		((FAIL_COUNT++)) || true
	fi
}

test_default_daemon() {
	echo -n "Test: default CMD is telldusd --nodaemon ... "
	docker inspect --format='{{.Config.Cmd}}' "$IMAGE" > "$TESTDIR/cmd.txt" 2>/dev/null || true
	if grep -q 'telldusd --nodaemon' "$TESTDIR/cmd.txt" 2>/dev/null; then
		echo "PASS"
		((PASS_COUNT++)) || true
	else
		echo "FAIL"
		((FAIL_COUNT++)) || true
	fi
}

test_oneshot_tdtool() {
	echo -n "Test: one-shot tdtool dispatch works ... "
	docker run --rm "$IMAGE" tdtool --help > "$TESTDIR/tdtool-help.txt" 2>/dev/null || true
	if grep -q 'tdtool' "$TESTDIR/tdtool-help.txt" 2>/dev/null; then
		echo "PASS"
		((PASS_COUNT++)) || true
	else
		echo "FAIL"
		((FAIL_COUNT++)) || true
	fi
}

test_no_build_tools() {
	echo -n "Test: no build tools in final image ... "
	docker run --rm --entrypoint sh "$IMAGE" -c "which gcc || which cmake || which g++" > "$TESTDIR/build-tools.txt" 2>/dev/null || true
	if [ -s "$TESTDIR/build-tools.txt" ]; then
		echo "FAIL"
		((FAIL_COUNT++)) || true
	else
		echo "PASS"
		((PASS_COUNT++)) || true
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
