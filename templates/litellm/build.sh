#!/bin/bash
set -e

# VARS
ALLOW_LIST=(
  "shared-prod01"
  "shared-test01"
  "local-test"
)
APP_NAME="litellm"
HELM_CHART_VERSION="1.82.6-nightly-latest"
HELM_REPOSITORY="litellm/litellm"
NAMESPACE="platform-litellm"

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
  true
}

pre_validate() {
  validate_helm_template
}

post_validate() {
  validate_helm_template "$DEPLOYMENT_DIR/install/install.yaml"
}

# Cluster-specific build customizations
build_shared-test01() {
  echo "Applying shared-test configurations for $APP_NAME"
  true
}

build_shared-prod01() {
  echo "Applying shared-production configurations for $APP_NAME"
  true
}

build_local-test() {
  echo "Applying local-test configurations for $APP_NAME"
  true
}

init "$@"
build
