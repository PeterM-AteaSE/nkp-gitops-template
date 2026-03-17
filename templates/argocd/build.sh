#!/bin/bash
set -e

# VARS
ALLOW_LIST=(
  "platform-prod01"
  "platform-test01"
  "local-test"
)
APP_NAME="argocd"
HELM_CHART_VERSION="9.4.2"
HELM_REPOSITORY="argo/argo-cd"
NAMESPACE="platform-argocd"

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
  mkdir -p "$DEPLOYMENT_DIR/eso"
  mkdir -p "$DEPLOYMENT_DIR/secrets"
  mkdir -p "$DEPLOYMENT_DIR/projects"
}

copy_files() {
  # Copy ESO store configuration and external secrets
  cp -r $SOURCE_DIR/eso/*.yaml $DEPLOYMENT_DIR/eso/
  cp -r $SOURCE_DIR/secrets/*.yaml $DEPLOYMENT_DIR/secrets/
  cp -r $SOURCE_DIR/projects/*.yaml $DEPLOYMENT_DIR/projects/
}

helm_template() {
  helm template "$APP_NAME" "$HELM_REPOSITORY" \
    --namespace "$NAMESPACE" \
    --version "$HELM_CHART_VERSION" \
    --include-crds \
    -f <(ytt -f values/values.yaml -f "${CLUSTER_CONFIG}" --ignore-unknown-comments) \
    > "$DEPLOYMENT_DIR/install/install.yaml"
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
  # Keep service port 443 - NetScaler uses Service targetPort (8080) for pod connection
  true
}

build_local-test() {
  echo "Applying local-test-specific configurations for $APP_NAME"
  true
}

# Call init and build
init "$@"
build
