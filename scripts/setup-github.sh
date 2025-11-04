#!/bin/bash

git config --global user.email "${GIT_EMAIL}"
git config --global user.name "${GIT_NAME}"

if [ -n "${GITHUB_TOKEN}" ]; then
    git config --global credential.helper store
    echo "https://${GITHUB_TOKEN}:x-oauth-basic@github.com" > ~/.git-credentials
    chmod 600 ~/.git-credentials
fi

exec "$@"