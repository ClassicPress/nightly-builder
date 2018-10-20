#!/usr/bin/env bash

(
	"$(dirname "$0")/build.sh" "$@"
	code=$?
	echo
	echo "Exit code: $code"
) > /tmp/nightly-build.log 2>&1
