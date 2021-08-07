#!/usr/bin/env bash

(
	set -e
	set -x

	if ! [ -x "$UPGRADE_API_SCRIPT" ]; then
		echo "Upgrade API script not found:"
		echo "'$UPGRADE_API_SCRIPT'"
		exit 1
	fi

	"$(dirname "$0")/build-step1.sh" "$@"
	code=$?
	echo
	echo "Build exit code: $code"

	if [ $code -eq 0 ]; then
		echo
		. "$(dirname "$0")/config.sh"
		echo "Running upgrade API script:"
		echo
		"$UPGRADE_API_SCRIPT"
		code=$?
		echo
		echo "Upgrade API script exit code: $code"
	fi
) > /tmp/nightly-build.log 2>&1
