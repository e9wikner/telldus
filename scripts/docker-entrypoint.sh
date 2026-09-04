#!/bin/sh
set -e

case "$1" in
	tdtool|tdadmin|telldusd)
		CMD="$1"
		shift
		exec "$CMD" "$@"
		;;
	telldus-mqtt)
		# telldusd runs in the background so this container can host both
		# processes; telldus-mqtt waits for /tmp/TelldusClient itself
		# (30s timeout, exits non-zero if telldusd never comes up) before
		# connecting, so no separate wait loop is needed here.
		telldusd --nodaemon &
		exec telldus-mqtt
		;;
	-*)
		exec telldusd "$@"
		;;
	*)
		exec telldusd --nodaemon "$@"
		;;
esac
