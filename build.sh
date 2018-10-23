#!/usr/bin/env bash

# Exit on error
set -e

# Verify that the server has its timezone set to UTC
date | grep ' UTC '

cd "$(dirname "$0")"

. config.sh
PUSH_URL="https://ClassyBot:${GITHUB_API_TOKEN}@github.com/ClassyBot/ClassicPress-nightly"

# Show commands as they are executed
set -x

pushd ClassicPress-nightly/
	git reset --hard
	git fetch origin
	git fetch origin --tags
	git checkout origin/migration -B migration
	git checkout origin/master -B master
popd

pushd ClassicPress/

	# Reset everything
	rm -rf build/ build-migration/
	git reset --hard
	git fetch origin
	git checkout origin/develop -B develop
	rm -rf node_modules/

	# Set up node version
	set +x
	echo 'loading nvm and node'
	. ~/.nvm/nvm.sh --no-use
	nvm use || nvm install
	set -x

	# Install dependencies and generate a nightly build
	npm install
	CLASSICPRESS_NIGHTLY=true ./node_modules/.bin/grunt build

	# Prepare the migration build in its own subfolder
	# 'build/' -> 'build-migration/wordpress/'
	cp -ar build/ wordpress/
	mkdir build-migration/
	mv wordpress/ build-migration/

	# Commit, push, and upload the migration build
	# Due to the special folder structure of this build, we have to build a zip
	# and upload it via GitHub's releases API, rather than letting GitHub build
	# the zip based on the tag.
	pushd build-migration/
		# Update the version string
		perl -pi -we 's/\+nightly\./+migration./' wordpress/wp-includes/version.php
		BUILD_TAG=$(grep '^\$cp_version' wordpress/wp-includes/version.php | cut -d"'" -f2)

		# Set up the git repository
		cp -ar ../../ClassicPress-nightly/.git/ .
		# Check out `migration` without touching the working tree
		git symbolic-ref HEAD refs/heads/migration
		# Create the commit and the tag
		git add --all .
		GIT_COMMITTER_NAME='ClassyBot' GIT_COMMITTER_EMAIL='bots@classicpress.net' \
			git commit --author 'ClassyBot <bots@classicpress.net>' \
			-m "Nightly migration build $BUILD_TAG"
		git tag "$BUILD_TAG"
		# Push the commit and the tag
		set +x
		echo "+ git push origin migration"
		git push "$PUSH_URL" migration
		echo "+ git push origin $BUILD_TAG"
		git push "$PUSH_URL" "$BUILD_TAG"
		set -x

		# Build the zip file
		BUILD_FILENAME="ClassicPress-nightly-$(echo "$BUILD_TAG" | tr '+' '-').zip"
		# HACK: `zip` is not installed on this server
		npm install @ffflorian/jszip-cli@2.1.1
		../node_modules/.bin/jszip-cli add --output "$BUILD_FILENAME" --level 9 wordpress/

		# Create the release using the GitHub API
		BUILD_COMMIT=$(git rev-parse HEAD)
		RESPONSE_CODE=$(curl \
			-X POST \
			-H 'Accept: application/vnd.github.v3+json' \
			-H "Authorization: token $GITHUB_API_TOKEN" \
			-H "Content-Type: application/json" \
			--data "{
				\"tag_name\": \"$BUILD_TAG\",
				\"target_commitish\": \"$BUILD_COMMIT\",
				\"body\": \"Nightly migration build $BUILD_TAG. You probably don't need this, it's just for use by the migration plugin.\"
			}" \
			--output release.json \
			--write-out '%{http_code}' \
			https://api.github.com/repos/ClassyBot/ClassicPress-nightly/releases \
		)
		if [ "$RESPONSE_CODE" -ne 201 ]; then
			echo "Failed to create release: HTTP $RESPONSE_CODE"
			cat release.json
			exit 1
		fi
		echo 'Created GitHub release'

		# Upload the zip using the GitHub API
		UPLOAD_URL=$(cat release.json | grep '"upload_url"' | cut -d'"' -f4 | cut -d'{' -f1)
		RESPONSE_CODE=$(curl \
			-X POST \
			-H 'Accept: application/vnd.github.v3+json' \
			-H "Authorization: token $GITHUB_API_TOKEN" \
			-H "Content-Type: application/zip" \
			--data-binary "@$BUILD_FILENAME" \
			--output upload.json \
			--write-out '%{http_code}' \
			"${UPLOAD_URL}?name=$BUILD_FILENAME"
		)
		if [ "$RESPONSE_CODE" -ne 201 ]; then
			echo "Failed to upload zip: HTTP $RESPONSE_CODE"
			cat upload.json
			exit 1
		fi
		echo 'Uploaded zip to GitHub'
	popd

	# Commit and push the nightly build
	# Do this *after* finishing the migration build, so that the nightly build
	# will show as the latest release on GitHub.  (GitHub's ordering of releases
	# is buggy, though.)
	pushd build/
		# Get the version string from the build
		BUILD_TAG=$(grep '^\$cp_version' wp-includes/version.php | cut -d"'" -f2)

		# Set up the git repository
		cp -ar ../../ClassicPress-nightly/.git/ .

		# Create the commit and the tag
		git add --all .
		GIT_COMMITTER_NAME='ClassyBot' GIT_COMMITTER_EMAIL='bots@classicpress.net' \
			git commit --author 'ClassyBot <bots@classicpress.net>' \
			-m "Nightly build $BUILD_TAG"
		git tag "$BUILD_TAG"

		# Push the commit and the tag
		set +x
		echo "+ git push origin master"
		git push "$PUSH_URL" master
		echo "+ git push origin $BUILD_TAG"
		git push "$PUSH_URL" "$BUILD_TAG"
		set -x

		# Add a GitHub release for the nightly build
		BUILD_COMMIT=$(git rev-parse HEAD)
		RESPONSE_CODE=$(curl \
			-X POST \
			-H 'Accept: application/vnd.github.v3+json' \
			-H "Authorization: token $GITHUB_API_TOKEN" \
			-H "Content-Type: application/json" \
			--data "{
				\"tag_name\": \"$BUILD_TAG\",
				\"target_commitish\": \"$BUILD_COMMIT\",
				\"body\": \"Nightly build $BUILD_TAG. Use the source code zip.\"
			}" \
			--output release.json \
			--write-out '%{http_code}' \
			https://api.github.com/repos/ClassyBot/ClassicPress-nightly/releases \
		)
		if [ "$RESPONSE_CODE" -ne 201 ]; then
			echo "Failed to create release: HTTP $RESPONSE_CODE"
			cat release.json
			exit 1
		fi
		echo 'Created GitHub release'
	popd
popd

pushd ClassicPress-nightly/
	git reset --hard
	git fetch origin
	git fetch origin --tags
	git checkout origin/migration -B migration
	git checkout origin/master -B master
popd
