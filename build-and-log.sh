#!/usr/bin/env bash

(
	"$(dirname "$0")/build.sh" "$@"
	code=$?
	echo
	echo "Exit code: $code"

	if [ $code -eq 0 ]; then
		echo
		. "$(dirname "$0")/config.sh"
		if [ -x "$UPGRADE_API_SCRIPT" ]; then
			echo "Running upgrade API script:"
			echo
			"$UPGRADE_API_SCRIPT"
			code=$?
			echo
			echo "Exit code: $code"
		else
			echo "Upgrade API script not found:"
			echo "'$UPGRADE_API_SCRIPT'"
		fi
	fi
) > /tmp/nightly-build.log 2>&1
