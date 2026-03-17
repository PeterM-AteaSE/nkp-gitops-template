#!/bin/bash
#set -x

# ArgoCD CLI helps to manage ArgoCD applications and clusters
# https://argo-cd.readthedocs.io/en/stable/cli_installation/
APP_NAME=argocd
RELEASE_VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)
RELEASE_URL="https://github.com/argoproj/argo-cd/releases/download/v${RELEASE_VERSION}/${APP_NAME}-linux-amd64"
sudo curl -sSLo "/usr/local/bin/${APP_NAME}" "${RELEASE_URL}" \
  && sudo chmod +x "/usr/local/bin/${APP_NAME}"
