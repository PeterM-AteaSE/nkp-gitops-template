#!/bin/bash

APP_NAME=kubeseal
RELEASE_VERSION=0.29.0
RELEASE_URL="https://github.com/bitnami-labs/sealed-secrets/releases/download/v${RELEASE_VERSION}/${APP_NAME}-${RELEASE_VERSION}-linux-amd64.tar.gz"
sudo curl -sSLo "${APP_NAME}.tar.gz" "${RELEASE_URL}" \
  && sudo tar xzvf "${APP_NAME}.tar.gz" -C /usr/local/bin/ "${APP_NAME}" \
  && sudo chmod +x "/usr/local/bin/${APP_NAME}" \
  && rm -f "${APP_NAME}.tar.gz"
