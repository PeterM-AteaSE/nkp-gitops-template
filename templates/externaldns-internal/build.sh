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
APP_NAME="externaldns-internal"
HELM_CHART_VERSION="1.20.0"
HELM_REPOSITORY="external-dns/external-dns"
NAMESPACE="platform-externaldns"

init() {
  # shellcheck source=/dev/null
  source "$(git rev-parse --show-toplevel)/utils/helpers.sh"
  # shellcheck source=/dev/null
  #source "$(git rev-parse --show-toplevel)/tests/run-tests.sh"
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
  mkdir -p "$DEPLOYMENT_DIR/configmaps"
  mkdir -p "$DEPLOYMENT_DIR/eso"
  mkdir -p "$DEPLOYMENT_DIR/secrets"
}

copy_files() {
  cp "$SOURCE_DIR/configmaps/krb5-conf.yaml" "$DEPLOYMENT_DIR/configmaps/"
  cp "$SOURCE_DIR/eso/eso-store-platform.yaml" "$DEPLOYMENT_DIR/eso/"
  cp "$SOURCE_DIR/secrets/kerberos-secret.yaml" "$DEPLOYMENT_DIR/secrets/"
}

helm_template() {
  helm template "$APP_NAME" "$HELM_REPOSITORY" \
    --namespace "$NAMESPACE" \
    --version "$HELM_CHART_VERSION" \
    --include-crds \
    --set=txtOwnerId="$CLUSTER" \
    -f "values/values.yaml" >"$DEPLOYMENT_DIR/install/install.yaml"
}

yaml_template() { true; }

pre_validate() {
  validate_helm_template
  #validate_yaml_template "$SOURCE_DIR/sealedsecret/externaldns-internal-credentials.yaml"
}

post_validate() {
  validate_helm_template "$DEPLOYMENT_DIR/install/install.yaml"
  validate_yaml_template "$DEPLOYMENT_DIR/configmaps/krb5-conf.yaml"
  validate_yaml_template "$DEPLOYMENT_DIR/eso/eso-store-platform.yaml"
  validate_yaml_template "$DEPLOYMENT_DIR/secrets/kerberos-secret.yaml"
  #validate_yaml_template "$DEPLOYMENT_DIR/sealedsecret/externaldns-internal-credentials.yaml"
}

build_platform-test01() { true; }
build_platform-prod01() { true; }
build_shared-test01() { true; }
build_shared-prod01() { true; }
build_local-test() { true; }

main() {
  init "$@"
  is_allowed "${ALLOW_LIST[*]}" "$CLUSTER"
  build
}

main "$@"
