#!/bin/bash

#######################################
# Checks if the cluster is in the allowed list
# Globals:
# Arguments:
#   an allow_list
#   a cluster
# Returns:
#   0 if ok, non-zero on error
#######################################
is_allowed() {
  local allow_list="$1"
  local cluster="$2"

  if [[ ! " ${allow_list[*]} " =~ [[:space:]]${cluster}[[:space:]] ]]; then
    echo "error: invalid argument, want one of ${allow_list[*]}, got: $cluster" \
      && return 1
  fi
}

#######################################
# Returns all the cluster elements
# Globals:
# Arguments:
# Returns:
#   Expands the cluster_list and returns all the elements
#######################################
export_cluster_list() {
  local cluster_list=()
  for file in "$GIT_ROOT_DIR"/clusters/*.yaml; do
    format_filename=$(basename "$file" .yaml)
    cluster_list+=("${format_filename}")
  done
  echo "${cluster_list[*]}"
}

#######################################
# Exports default vars for build
# Globals:
#   CLUSTER
#   CLUSTER_CONFIG
#   DEPLOYMENT_DIR
#   KUBERNETES_CONTEXT
#   SEALEDSECRETS_CONTROLLER
#   SEALEDSECRETS_NAMESPACE
#   SOURCE_DIR
# Arguments:
#   A cluster name
# Returns:
#######################################
export_cluster_vars() {
  CLUSTER="$1"
  export CLUSTER

  CLUSTER_CONFIG="$GIT_ROOT_DIR/clusters/$CLUSTER.yaml"
  export CLUSTER_CONFIG

  DEPLOYMENT_DIR="$GIT_ROOT_DIR/deployments/$CLUSTER/$APP_NAME"
  export DEPLOYMENT_DIR

  #KUBERNETES_CONTEXT="blabla-$1@blabla-$1"
  #export KUBERNETES_CONTEXT

  #SEALEDSECRETS_CONTROLLER="sealedsecrets-sealed-secrets"
  #export SEALEDSECRETS_CONTROLLER

  #SEALEDSECRETS_NAMESPACE="sealedsecrets"
  #export SEALEDSECRETS_NAMESPACE

  SOURCE_DIR="$GIT_ROOT_DIR/templates/$APP_NAME"
  export SOURCE_DIR
}

#######################################
# Exports the git root directory
# Globals:
#   GIT_ROOT_DIR
# Arguments:
# Returns:
#######################################
export_git_root_dir() {
  GIT_ROOT_DIR=$(git rev-parse --show-toplevel)
  export GIT_ROOT_DIR
}

#######################################
# Generates helm values file to values/new-values.yaml
# Globals:
# Arguments:
#    a release name
#    a helm repository/chart
#    chart version
# Returns:
#   0 or 200 if ok, non zero or 200 on error
#######################################
generate_helm_values() {
  local APP_NAME="$1"
  local HELM_REPOSITORY="$2"
  local HELM_CHART_VERSION="$3"
  local HELM_CHART_LATEST_VERSION
  HELM_CHART_LATEST_VERSION=$(helm search repo "$HELM_REPOSITORY" | awk 'NR==2 {print $2}')

  # Below can be done with any cluster, it is only done to get $SOURCE_DIR
  export_cluster_vars platform-test01

  if [[ -z "$HELM_REPOSITORY" ]] || [[ -z "$HELM_CHART_VERSION" ]]; then
    echo "error: missing HELM_REPOSITORY or HELM_CHART_VERSION" \
      && return 1
  fi

  if ! helm show values "$HELM_REPOSITORY" --version "$HELM_CHART_VERSION" >"$SOURCE_DIR"/values/new-values.yaml; then
    return 1
  fi

  if ! validate_yaml_template "$SOURCE_DIR"/values/new-values.yaml; then
    return 1
  fi

  echo "info: run 'helm repo update' if you haven't already."
  echo "info: latest version: $HELM_CHART_LATEST_VERSION, script version: $HELM_CHART_VERSION"
  echo "info: generated helm values file for $APP_NAME $HELM_REPOSITORY $HELM_CHART_VERSION"
  return 200
}

#######################################
# Validates the cluster name
# Globals:
# Arguments:
#   a cluster list (expanded) or "values" to generate new helm values file for the specified version
# Returns:
#   0 if ok, non-zero on error
#######################################
validate_args() {

  if [[ "$1" = "value" || "$1" = "values" || "$1" = "new_values" || "$1" = "new-values" ]]; then
    generate_helm_values "$APP_NAME" "$HELM_REPOSITORY" "$HELM_CHART_VERSION"
  fi

  local CLUSTER_LIST=()
  read -r -a CLUSTER_LIST <<<"$(export_cluster_list)"
  # printf '%s\n' "${CLUSTER_LIST[*]}"

  if [[ -z "$1" ]]; then
    echo "error: invalid argument, want one of ${CLUSTER_LIST[*]} or values, got: $1" \
      && return 1
  fi

  if [[ ! " ${CLUSTER_LIST[*]} " =~ [[:space:]]${1}[[:space:]] ]]; then
    echo "error: invalid argument, want one of ${CLUSTER_LIST[*]}, got: $1" \
      && return 1
  fi
}

#######################################
# Validates the kubernetes context
# Globals:
# Arguments:
#   A Kubernetes context
# Returns:
#   0 if ok, non-zero on error
#######################################
validate_kubernetes_context() {
  local kube_context="$1"
  if [[ -z "${kube_context}" ]]; then
    echo "error: invalid argument, want a KUBE_CONTEXT, got: $1" \
      && return 1
  fi

  if ! kubectl config get-contexts "${kube_context}" >/dev/null 2>&1; then
    echo "error: invalid argument, want a KUBE_CONTEXT, got: $1" \
      && return 1
  fi
}

#######################################
# Validates binary version arg
# Globals:
# Arguments:
#   A version, for example 0.25.1
# Returns:
#   0 if ok, non-zero on error
#######################################
validate_args_bin() {
  if [[ -z "$1" ]]; then
    echo "error: invalid argument, want a version, example: 0.24.5, got: $1" \
      && return 1
  fi
}

#######################################
# Checks if git hooks are configured
# Globals:
# Arguments:
# Returns:
#   0 if ok, non-zero on error
#######################################
check_githook() {
  if [ "$(git config --local core.hooksPath)" != ".githooks" ]; then
    echo "error: githooks are not configured, run the setup script" \
      && return 1
  fi
}

#######################################
# Validates the yaml length
# Globals:
# Arguments:
#   a .yaml template file
# Returns:
#   0 if ok, non-zero on error
#######################################
validate_yaml_length() {
  local template_file="$1"

  if [ -n "$template_file" ] && ! [ -s "$template_file" ] && [ "$(wc -c <"$template_file")" -le 5 ]; then
    echo "error: .yaml file is empty or does not exist" \
      && return 1
  fi
}

#######################################
# Validates the yaml file using kubectl
# Globals:
# Arguments:
#   a .yaml template file
# Returns:
#   0 if ok, non-zero on error
#######################################
validate_yaml_kubectl_client() {
  local template_file="$1"
  if ! kubectl apply --dry-run=client -f "$template_file"; then
    {
      return 1
    }
  fi
}

#######################################
# Validates helm template files
# Globals:
# Arguments:
#   a .yaml template file
# Returns:
#   0 if ok, non-zero on error
#######################################
validate_helm_template() {
  validate_yaml_length "$1"
}

#######################################
# Validates yaml files
# Globals:
# Arguments:
#   a .yaml template file
# Returns:
#   0 if ok, non-zero on error
#######################################
validate_yaml_template() {
  validate_yaml_length "$1"
}

#######################################
# Checks if all pods are in a running state
# Globals:
# Arguments:
#   A namespace
#   A kubernetes context
# Returns:
#   0 if ok, non-zero on error
#######################################
check_all_pods_running() {
  not_running_pods=$(kubectl get pods -n "$1" --context "$2" --field-selector status.phase!=Running 2>/dev/null)

  if ! $not_running_pods; then
    echo "Pods are not in a running state"
    return 1
  fi
}

#######################################
# Check DNS record
# Globals:
# Arguments:
#   A DNS name
#   A DNS Server
# Returns:
#   0 if ok, non-zero on error
#######################################
check_dns_record() {
  local DNS_RECORD=$1
  local NAMESERVER=$2

  nslookup "$DNS_RECORD" "$NAMESERVER" >/dev/null 2>&1
  return $?
}

#######################################
# Check HTTP status for status ok without tls verify
# Globals:
# Arguments:
#   A DNS name
# Returns:
#   0 if ok, non-zero on error
#######################################
check_http_status() {
  local DNS_RECORD=$1
  local WANT_HTTP_CODE=200

  HTTP_CODE=$(curl -ks -o /dev/null -w "%{http_code}" "$DNS_RECORD")
  if [[ "$HTTP_CODE" -eq "$WANT_HTTP_CODE" ]]; then
    return 0
  else
    echo "check_http_status: want: $WANT_HTTP_CODE, got: $HTTP_CODE"
    return 1
  fi
}

#######################################
# Checks if you are logged in to a registy with podman
# Globals:
# Arguments:
#   Registry
# Returns:
#   0 if ok, non-zero on error
#######################################
is_podman_login() {
  podman login --get-login "$1" 1>/dev/null
}

#######################################
# Checks if bin is in path
# Globals:
# Arguments:
#   bin name
# Returns:
#   0 if ok, non-zero on error
#######################################
check_binary() {
  BINARY=$1
  if ! command -v "$BINARY" &>/dev/null; then
    echo "error: command or binary not found: $BINARY" \
      && return 127
  fi
}

#######################################
# Print test results
# Globals:
#   PASSED
#   FAILED
# Arguments:
# Returns:
#   0 if ok, non-zero on error
#######################################
# TODO: Fix total number of tests run, the tests will exit before all cases run
#  Need to store the total number of cases prior to running
results() {
  if [ -z "$PASSED" ]; then
    PASSED=0
  fi

  if [ -z "$FAILED" ]; then
    FAILED=0
  fi

  echo
  if [ "$FAILED" -gt 0 ]; then
    echo "test summary: Passed: $PASSED, Failed: $FAILED, Total: $((PASSED + FAILED))" >&2
    return 1
  else
    echo "test summary: Passed: $PASSED, Failed: $FAILED, Total: $((PASSED + FAILED))"
    return 0
  fi
}

#######################################
# Run function with backoff
# Globals:
# Arguments:
#   Function name
#   Arguments..
# Returns:
#   0 if ok, non-zero on error
#######################################
with_backoff() {
  set +e

  local MAX_ATTEMPTS=5
  local TIMEOUT=5
  local ATTEMPT=1
  local EXIT_CODE=0

  echo "with_backoff: $*"

  while [[ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]]; do
    "$@"
    EXIT_CODE=$?

    if [[ $EXIT_CODE == 0 ]]; then
      break
    fi

    echo "error: test failed: $*, Retrying in $TIMEOUT" >&2
    sleep "$TIMEOUT"
    ATTEMPT=$((ATTEMPT + 1))
    TIMEOUT=$((TIMEOUT + 5))
  done

  set -e

  if [[ $EXIT_CODE != 0 ]]; then
    echo "error: test failed: $*" >&2
    FAILED=$((FAILED + 1))
    return $EXIT_CODE
  fi

  PASSED=$((PASSED + 1))
  return $EXIT_CODE
}

main() {
  export_git_root_dir
}

main "$@"
