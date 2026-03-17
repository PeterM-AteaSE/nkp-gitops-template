#!/bin/bash
set -e

# VARS
ALLOW_LIST=(
  "platform-prod01"
  "local-test"
)
APP_NAME="argocd-apps"

init() {
  # shellcheck source=/dev/null
  source "$(git rev-parse --show-toplevel)/utils/helpers.sh"
  # shellcheck source=/dev/null
  #source "$(git rev-parse --show-toplevel)/tests/run-tests.sh"
  check_githook
  validate_args "$@"
  export_cluster_vars "$@"
  # INFO: Overriding global var
  ARGOAPPS_DIR="$DEPLOYMENT_DIR/argocd-apps"
  # DEPLOYMENT_DIR="$GIT_ROOT_DIR/deployments/$CLUSTER/$APP_NAME"
  # export DEPLOYMENT_DIR
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
  mkdir -p "$DEPLOYMENT_DIR/cluster-all-apps"
  mkdir -p "$DEPLOYMENT_DIR/argocd"
  mkdir -p "$DEPLOYMENT_DIR/netscaler-ingress"
  mkdir -p "$DEPLOYMENT_DIR/external-secrets-operator"
  mkdir -p "$DEPLOYMENT_DIR/adcs-issuer"
  #mkdir -p "$DEPLOYMENT_DIR/externaldns-internal"
}

copy_files() { true; }

helm_template() { true; }

yaml_template() {
  ytt -f "$CLUSTER_CONFIG" -f "$SOURCE_DIR/cluster-all-apps/cluster-all-apps.yaml" --ignore-unknown-comments --implicit-map-key-overrides >"$DEPLOYMENT_DIR/cluster-all-apps/$CLUSTER-all-apps.yaml"
  ytt -f "$CLUSTER_CONFIG" -f "$SOURCE_DIR/netscaler-ingress/netscaler-ingress.yaml" --ignore-unknown-comments --implicit-map-key-overrides >"$DEPLOYMENT_DIR/netscaler-ingress/$CLUSTER-netscaler-ingress.yaml"
  ytt -f "$CLUSTER_CONFIG" -f "$SOURCE_DIR/external-secrets-operator/external-secrets-operator.yaml" --ignore-unknown-comments --implicit-map-key-overrides >"$DEPLOYMENT_DIR/external-secrets-operator/$CLUSTER-external-secrets-operator.yaml"
  ytt -f "$CLUSTER_CONFIG" -f "$SOURCE_DIR/adcs-issuer/adcs-issuer.yaml" --ignore-unknown-comments --implicit-map-key-overrides >"$DEPLOYMENT_DIR/adcs-issuer/$CLUSTER-adcs-issuer.yaml"
  #ytt -f "$CLUSTER_CONFIG" -f "$SOURCE_DIR/externaldns-internal/externaldns-internal.yaml" --ignore-unknown-comments --implicit-map-key-overrides >"$DEPLOYMENT_DIR/externaldns-internal/externaldns-internal.yaml"
}

pre_validate() {
  validate_helm_template
  validate_yaml_template
}

post_validate() {
  validate_helm_template
  validate_yaml_template
}

build_platform-prod01() {
  ytt -f "$CLUSTER_CONFIG" -f "$SOURCE_DIR/argocd/argocd.yaml" --ignore-unknown-comments --implicit-map-key-overrides >"$DEPLOYMENT_DIR/argocd/$CLUSTER-argocd.yaml"
}

build_platform-test01() { true; }

build_shared-prod01() { true; }

build_shared-test01() { true; }

build_local-test() { true; } 

main() {
  init "$@"
  is_allowed "${ALLOW_LIST[*]}" "$CLUSTER"
  build
}

main "$@"
