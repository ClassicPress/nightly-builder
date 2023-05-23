#!/usr/bin/env bash

# Exit on error
set -e

# Show commands as they are executed
set -x

# Verify that the server has its timezone set to UTC
date | grep -P ' UTC(\s|$)'

cd "$(dirname "$0")"

. config.sh
PUSH_URL="https://ClassyBot:${GITHUB_API_TOKEN}@github.com/ClassyBot/ClassicPress-v2-nightly"

pushd ClassicPress-v2-nightly/
	git reset --hard
	git fetch origin
	git fetch origin --tags
	#git checkout origin/migration -B migration
	git checkout origin/develop -B develop
popd

pushd ClassicPress-v2/

	# Reset everything
	rm -rf build/ build-migration/
	git reset --hard
	git fetch origin
	git checkout origin/develop -B develop
	rm -rf node_modules/

	# Store the commit URL of the development repo
	DEV_COMMIT_URL="https://github.com/ClassicPress/ClassicPress-v2/commit/$(git rev-parse HEAD)"

	# API server needs lover version of NVM
	echo '16.19.0' > .nvmrc

	# Set up node version
	set +x
	echo 'loading nvm and node'
	. ~/.nvm/nvm.sh --no-use
	nvm use || nvm install
	set -x

	# Install dependencies and generate a nightly build
	npm install
	CLASSICPRESS_NIGHTLY=true ./node_modules/.bin/grunt build

	# Commit and push the nightly build
	# Do this *after* finishing the migration build, so that the nightly build
	# will show as the latest release on GitHub.  (GitHub's ordering of releases
	# is buggy, though.)
	pushd build/
		# Get the version string from the build
		BUILD_TAG=$(grep '^\$cp_version' wp-includes/version.php | cut -d"'" -f2)

		# Set up the git repository
		cp -ar ../../ClassicPress-v2-nightly/.git/ .

		# Create the commit and the tag
		git add --all .
		GIT_COMMITTER_NAME='ClassyBot' GIT_COMMITTER_EMAIL='bots@classicpress.net' \
			git commit --author 'ClassyBot <bots@classicpress.net>' \
			-m "Nightly build $BUILD_TAG"
		GIT_COMMITTER_NAME='ClassyBot' GIT_COMMITTER_EMAIL='bots@classicpress.net' \
			GIT_AUTHOR_NAME='ClassyBot' GIT_AUTHOR_EMAIL='bots@classicpress.net' \
			git tag "$BUILD_TAG" -m "Nightly build tag $BUILD_TAG"

		# Push the commit and the tag
		set +x
		echo "+ git push origin develop"
		git push "$PUSH_URL" develop
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
				\"body\": \"Nightly build $BUILD_TAG. Use the source code zip.\\n\\nSource commit: $DEV_COMMIT_URL\"
			}" \
			--output release.json \
			--write-out '%{http_code}' \
			https://api.github.com/repos/ClassyBot/ClassicPress-v2-nightly/releases \
		)
		if [ "$RESPONSE_CODE" -ne 201 ]; then
			echo "Failed to create release: HTTP $RESPONSE_CODE"
			cat release.json
			exit 1
		fi
		echo 'Created GitHub release'
	popd
popd

pushd ClassicPress-v2-nightly/
	git reset --hard
	git fetch origin
	git fetch origin --tags
	#git checkout origin/migration -B migration
	git checkout origin/develop -B develop
popd
