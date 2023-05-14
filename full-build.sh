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

	for gh_repo in ClassicPress/ClassicPress-v2 ClassyBot/ClassicPress-nightly-v2; do
		user="$(echo "$gh_repo" | cut -d/ -f1)"
		repo="$(echo "$gh_repo" | cut -d/ -f2)"
		if ! [ -d "$repo/.git" ]; then
			git clone "https://github.com/$user/$repo" "$repo"
		fi
	done

	set +e
	./build-step1.sh "$@"
	code=$?
	echo
	echo "Build exit code: $code"
) > /tmp/nightly-build.log 2>&1
