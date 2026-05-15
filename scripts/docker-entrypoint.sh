#!/bin/sh
set -e

if [ "$1" = "tdtool" ]; then
	CMD="$1"
	shift
	exec "$CMD" "$@"
fi

if [ "$1" = "tdadmin" ]; then
	CMD="$1"
	shift
	exec "$CMD" "$@"
fi

exec telldusd --nodaemon "$@"
