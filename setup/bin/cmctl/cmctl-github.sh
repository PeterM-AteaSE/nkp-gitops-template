#!/bin/bash

APP_NAME=cmctl
RELEASE_VERSION=2.0.0
RELEASE_URL="https://github.com/cert-manager/cmctl/releases/download/v${RELEASE_VERSION}/${APP_NAME}_linux_amd64"
sudo curl -sSLo "/usr/local/bin/${APP_NAME}" "${RELEASE_URL}" \
  && sudo chmod +x "/usr/local/bin/${APP_NAME}"
