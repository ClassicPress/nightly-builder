#!/usr/bin/env bash

(
	set -e
	set -x

	if ! [ -x "$UPGRADE_API_SCRIPT" ]; then
		echo "Upgrade API script not found:"
		echo "'$UPGRADE_API_SCRIPT'"
		exit 1
	fi

	cd "$(dirname "$0")"

	for gh_repo in ClassicPress/ClassicPress ClassyBot/ClassicPress-nightly; do
		user="$(echo "$gh_repo" | cut -d/ -f1)"
		repo="$(echo "$gh_repo" | cut -d/ -f2)"
		if ! [ -d "$repo/.git" ]; then
			git clone "https://github.com/$user/$repo" "$repo"
		fi
	done

	./build-step1.sh "$@"
	code=$?
	echo
	echo "Build exit code: $code"

	if [ $code -eq 0 ]; then
		echo
		. config.sh
		echo "Running upgrade API script:"
		echo
		"$UPGRADE_API_SCRIPT"
		code=$?
		echo
		echo "Upgrade API script exit code: $code"
	fi
) > /tmp/nightly-build.log 2>&1
