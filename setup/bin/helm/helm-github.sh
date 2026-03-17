#!/bin/bash

APP_NAME=helm
RELEASE_VERSION=3.16.3
RELEASE_URL="https://get.helm.sh/${APP_NAME}-v${RELEASE_VERSION}-linux-amd64.tar.gz"
sudo curl -sSLo "${APP_NAME}.tar.gz" "${RELEASE_URL}" \
  && sudo tar xzvf "${APP_NAME}.tar.gz" -C /usr/local/bin/ --strip-components 1 "linux-amd64/${APP_NAME}" \
  && sudo chmod +x "/usr/local/bin/${APP_NAME}" \
  && rm -f "${APP_NAME}.tar.gz"
