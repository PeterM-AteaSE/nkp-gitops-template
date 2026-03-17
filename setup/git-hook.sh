#!/bin/bash
set -e

#######################################
# Configures githooks for this repository
# Globals:
# Arguments:
# Returns:
#   0 if ok, non-zero on error
#######################################
configure_git_hooks() {
  git config --local core.hooksPath .githooks
}

#######################################
# Configures git eol to lf
# Globals:
# Arguments:
# Returns:
#   0 if ok, non-zero on error
#######################################
configure_eol() {
  git config --local core.autocrlf false
  git config --local core.eol lf
}

main() {
  configure_git_hooks
  configure_eol
}

main
