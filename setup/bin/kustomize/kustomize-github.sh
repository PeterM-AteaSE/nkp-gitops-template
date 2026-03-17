#!/bin/bash

APP_NAME=kustomize
RELEASE_VERSION=5.5.0
RELEASE_URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${RELEASE_VERSION}/${APP_NAME}_v${RELEASE_VERSION}_linux_amd64.tar.gz"
sudo curl -sSLo "${APP_NAME}.tar.gz" "${RELEASE_URL}" \
  && sudo tar xzvf "${APP_NAME}.tar.gz" -C /usr/local/bin/ "${APP_NAME}" \
  && sudo chmod +x "/usr/local/bin/${APP_NAME}" \
  && rm -f "${APP_NAME}.tar.gz"
