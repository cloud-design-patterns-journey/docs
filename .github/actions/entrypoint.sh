#!/usr/bin/env sh

cd "${GITHUB_WORKSPACE}"

pip install -r requirements.txt

git config --global --add safe.directory /github/workspace
npm ci
npm run build
