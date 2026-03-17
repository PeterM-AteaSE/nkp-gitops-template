#!/bin/bash
set -e

#######################################
# Adds helm required repositories
# Globals:
# Arguments:
# Returns:
#   0 if ok, non-zero on error
#######################################
add_helm_repositories() {
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo add bitnami https://charts.bitnami.com/bitnami
  #helm repo add cert-manager-webhook-infoblox-wapi https://sarg3nt.github.io/cert-manager-webhook-infoblox-wapi
  helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
  helm repo add grafana https://grafana.github.io/helm-charts
  helm repo add harbor https://helm.goharbor.io
  #helm repo add minio-operator https://operator.min.io
  helm repo add netscaler https://netscaler.github.io/netscaler-helm-charts/
  #helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add prometheus-msteams https://prometheus-msteams.github.io/prometheus-msteams/
  #helm ADCS Issuer (Microsoft Active Directory Certificate Services)
  helm repo add djkormo-adcs-issuer https://djkormo.github.io/adcs-issuer/
  helm repo add open-webui https://helm.openwebui.com/
  helm repo add otwld https://helm.otwld.com/
  helm repo add external-secrets https://charts.external-secrets.io
}

#######################################
# Updates helm repositories
# Globals:
# Arguments:
# Returns:
#   0 if ok, non-zero on error
#######################################
update_helm_repositories() {
  helm repo update
}

main() {
  echo "# Adding helm repositories"
  add_helm_repositories
  echo "# Updating helm repositories"
  update_helm_repositories
}

main
