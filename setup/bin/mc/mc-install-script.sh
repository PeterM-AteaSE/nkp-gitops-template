#!/bin/bash

APP_NAME=mc
RELEASE_URL="https://dl.min.io/client/mc/release/linux-amd64/mc"
sudo curl -sSLo "/usr/local/bin/${APP_NAME}" "${RELEASE_URL}" \
  && sudo chmod +x "/usr/local/bin/${APP_NAME}"
