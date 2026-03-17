#!/bin/bash

APP_NAME=yq
RELEASE_VERSION=4.44.5
RELEASE_URL="https://github.com/mikefarah/yq/releases/download/v${RELEASE_VERSION}/${APP_NAME}_linux_amd64"
sudo curl -sSLo "/usr/local/bin/${APP_NAME}" "${RELEASE_URL}" \
  && sudo chmod +x "/usr/local/bin/${APP_NAME}"
