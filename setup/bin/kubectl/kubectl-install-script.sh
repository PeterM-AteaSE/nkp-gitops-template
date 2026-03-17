#!/bin/bash

APP_NAME=kubectl
RELEASE_VERSION=1.29.11
RELEASE_URL="https://dl.k8s.io/release/v${RELEASE_VERSION}/bin/linux/amd64/${APP_NAME}"
sudo curl -sSLo "/usr/local/bin/${APP_NAME}" "${RELEASE_URL}" \
  && sudo chmod +x "/usr/local/bin/${APP_NAME}"
