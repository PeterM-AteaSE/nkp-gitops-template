#!/bin/bash
set -e

# VARS
ALLOW_LIST=(
  "platform-prod01"
  "platform-test01"
  "shared-prod01"
  "shared-test01"
  "local-test"
)
APP_NAME="cert-manager"
HELM_CHART_VERSION="1.16.2"
HELM_REPOSITORY="jetstack/cert-manager"
NAMESPACE="platform-cert-manager"

init() {
  # shellcheck source=/dev/null
  source "$(git rev-parse --show-toplevel)/utils/helpers.sh"
  check_githook
  validate_args "$@"
  export_cluster_vars "$@"
}

build() {
  echo "Building $APP_NAME for $CLUSTER"
  pre_validate
  create_dirs
  copy_files
  yaml_template
  helm_template
  eval "build_$CLUSTER"
  post_validate
}

create_dirs() {
  mkdir -p "$DEPLOYMENT_DIR/install"
  mkdir -p "$DEPLOYMENT_DIR/issuers"
}

copy_files() {
  # Copy cluster issuers if needed
  # cp "$SOURCE_DIR/issuers/letsencrypt-prod.yaml" "$DEPLOYMENT_DIR/issuers/"
  true
}

helm_template() {
  helm template "$APP_NAME" "$HELM_REPOSITORY" \
    --namespace "$NAMESPACE" \
    --version "$HELM_CHART_VERSION" \
    --include-crds \
    --set installCRDs=true \
    -f "values/values.yaml" >"$DEPLOYMENT_DIR/install/install.yaml"
}

yaml_template() { 
  # Use ytt templating if needed
  true
}

pre_validate() {
  validate_helm_template
}

post_validate() {
  validate_helm_template "$DEPLOYMENT_DIR/install/install.yaml"
}

# Cluster-specific build customizations
build_platform-test01() {
  echo "Applying test-specific configurations for $APP_NAME"
  # Use staging Let's Encrypt for test
  true
}

build_platform-prod01() {
  echo "Applying production-specific configurations for $APP_NAME"
  # Use production Let's Encrypt
  true
}

build_shared-test01() {
  echo "Applying shared-test configurations for $APP_NAME"
  true
}

build_shared-prod01() {
  echo "Applying shared-production configurations for $APP_NAME"
  true
}

build_local-test() {
  echo "Applying local test configurations for $APP_NAME"
  true
}

main() {
  init "$@"
  is_allowed "${ALLOW_LIST[*]}" "$CLUSTER"
  build
}

main "$@"
