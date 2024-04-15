#!/usr/bin/env sh

cd "${GITHUB_WORKSPACE}"

pip install -r requirements.txt

npm ci
npm run build
