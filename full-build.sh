#!/usr/bin/env bash

(
	set -e
	set -x

	cd "$(dirname "$0")"
	. config.sh

	if ! [ -x "$UPGRADE_API_SCRIPT" ]; then
		echo "Upgrade API script not found:"
		echo "'$UPGRADE_API_SCRIPT'"
		exit 1
	fi

	for gh_repo in ClassicPress/ClassicPress-v1 ClassyBot/ClassicPress-v1-nightly ClassicPress/ClassicPress-v2 ClassyBot/ClassicPress-v2-nightly; do
		user="$(echo "$gh_repo" | cut -d/ -f1)"
		repo="$(echo "$gh_repo" | cut -d/ -f2)"
		if ! [ -d "$repo/.git" ]; then
			git clone "https://github.com/$user/$repo" "$repo"
		fi
	done

	set +e
	./build-step-v1.sh "$@"
	code=$?
	echo
	echo "Build v1 exit code: $code"

	./build-step-v2.sh "$@"
	code2=$?
	echo
	echo "Build v2 exit code: $code1"

	if [ $code -eq 0 ] && [ $code2 -eq 0 ]; then
		echo
		echo "Running upgrade API script:"
		echo
		"$UPGRADE_API_SCRIPT"
		code=$?
		echo
		echo "Upgrade API script exit code: $code"
	fi
) > /tmp/nightly-build.log 2>&1
