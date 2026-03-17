#!/bin/bash

# konfig helps to merge, split or import kubeconfig files
# https://github.com/corneliusweig/konfig
APP_NAME=konfig
RELEASE_VERSION=0.2.6
RELEASE_URL="https://github.com/corneliusweig/konfig/raw/v${RELEASE_VERSION}/${APP_NAME}"
sudo curl -sSLo "/usr/local/bin/${APP_NAME}" "${RELEASE_URL}" \
  && sudo chmod +x "/usr/local/bin/${APP_NAME}"
