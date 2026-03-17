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
APP_NAME="external-secrets-operator"
HELM_CHART_VERSION="1.3.1"
HELM_REPOSITORY="external-secrets/external-secrets"
NAMESPACE="platform-eso"

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
}

copy_files() {
  true
}

helm_template() {
  helm template "$APP_NAME" "$HELM_REPOSITORY" \
    --namespace "$NAMESPACE" \
    --version "$HELM_CHART_VERSION" \
    --include-crds \
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
