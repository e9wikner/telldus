#!/bin/sh
set -e

case "$1" in
	tdtool|tdadmin|telldusd)
		CMD="$1"
		shift
		exec "$CMD" "$@"
		;;
	-*)
		exec telldusd "$@"
		;;
	*)
		exec telldusd --nodaemon "$@"
		;;
esac
