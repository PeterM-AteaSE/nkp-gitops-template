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
APP_NAME="adcs-issuer"
HELM_CHART_VERSION="2.1.5"
HELM_REPOSITORY="djkormo-adcs-issuer/adcs-issuer"
NAMESPACE="platform-adcs-issuer"

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
  mkdir -p "$DEPLOYMENT_DIR/clusterissuers"
  mkdir -p "$DEPLOYMENT_DIR/eso"
}

copy_files() {
  # Copy ESO store
  cp -r "$SOURCE_DIR/eso/"*.yaml "$DEPLOYMENT_DIR/eso/" 2>/dev/null || true
  # Copy ExternalSecret for ADCS credentials
  cp "$SOURCE_DIR/clusterissuers/adcs-credentials-secret.yaml" "$DEPLOYMENT_DIR/clusterissuers/"
  cp "$SOURCE_DIR/clusterissuers/example-certificate.yaml" "$DEPLOYMENT_DIR/clusterissuers/"
}

helm_template() {
  helm template "$APP_NAME" "$HELM_REPOSITORY" \
    --namespace "$NAMESPACE" \
    --version "$HELM_CHART_VERSION" \
    --include-crds \
    -f "values/values.yaml" >"$DEPLOYMENT_DIR/install/install.yaml"
}

yaml_template() {
  ytt -f "$CLUSTER_CONFIG" -f "$SOURCE_DIR/clusterissuers/clusteradcsissuer.yaml" \
    --ignore-unknown-comments --implicit-map-key-overrides \
    >"$DEPLOYMENT_DIR/clusterissuers/clusteradcsissuer.yaml"
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
  true
}

build_platform-prod01() {
  echo "Applying production-specific configurations for $APP_NAME"
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
