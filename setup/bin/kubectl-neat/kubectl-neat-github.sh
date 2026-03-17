#!/bin/bash

APP_NAME=kubectl-neat
RELEASE_VERSION=2.0.3
RELEASE_URL="https://github.com/itaysk/kubectl-neat/releases/download/v${RELEASE_VERSION}/${APP_NAME}_linux_amd64.tar.gz"
sudo curl -sSLo "${APP_NAME}.tar.gz" "${RELEASE_URL}" \
  && sudo tar xzvf "${APP_NAME}.tar.gz" -C /usr/local/bin/ "${APP_NAME}" \
  && sudo chmod +x "/usr/local/bin/${APP_NAME}" \
  && rm -f "${APP_NAME}.tar.gz"
