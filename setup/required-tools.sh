#!/bin/bash
set -e

# shellcheck source=/dev/null
source "$(git rev-parse --show-toplevel)/utils/helpers.sh"

main() {
  echo "# Checking if required binaries are present"
  check_binary curl
  check_binary git
  check_binary helm
  check_binary konfig
  check_binary kubectl
  check_binary kubectl-neat
  #check_binary kubeseal
  check_binary kustomize
  #check_binary mc
  check_binary nslookup
  check_binary shasum
  check_binary ytt
  check_binary yq
  # if check_binary code; then
  #   if ! code --list-extensions | grep -q "editorconfig.editorconfig"; then
  #     echo "error: missing vscode extension: editorconfig.editorconfig" \
  #       && return 127
  #   fi
  # fi
}

main
