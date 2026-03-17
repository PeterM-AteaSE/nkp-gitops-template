#!/usr/bin/env bash
###############################################################################
# register-argocd-cluster.sh
#
# Automates the deployment of ArgoCD manager ServiceAccount and credential
# extraction for cluster registration.
#
# Usage:
#   ./register-argocd-cluster.sh <cluster-name> [--vault-name <vault>] [--context <context>]
#
# Example:
#   ./register-argocd-cluster.sh platform-prod01
#   ./register-argocd-cluster.sh platform-test01 --vault-name <AZURE_KEY_VAULT_NAME> --context platform-t01
#
# This script will:
# 1. Apply ArgoCD manager RBAC resources (rbac-core)
# 2. Wait for token secret to be created
# 3. Extract bearer token and CA certificate
# 4. Store credentials in Azure Key Vault
# 5. Verify storage and provide summary
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VAULT_NAME="${VAULT_NAME:-<AZURE_KEY_VAULT_NAME>}"
KUBECTL_CONTEXT=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RBAC_CORE_DIR="${REPO_ROOT}/templates/argocd/rbac-core"

###############################################################################
# Functions
###############################################################################

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

usage() {
    cat << EOF
Usage: $(basename "$0") <cluster-name> [OPTIONS]

Automates ArgoCD cluster registration by deploying RBAC resources and
extracting credentials to Azure Key Vault.

Arguments:
  <cluster-name>    Name of the cluster (e.g., platform-prod01)

Options:
  --vault-name <name>   Azure Key Vault name (default: <AZURE_KEY_VAULT_NAME>)
  --context <context>   kubectl context to use (default: current context)
  -h, --help           Show this help message

Environment Variables:
  VAULT_NAME           Default Key Vault name

Examples:
  $(basename "$0") platform-prod01
  $(basename "$0") platform-test01 --vault-name <AZURE_KEY_VAULT_NAME>
  $(basename "$0") shared-prod01 --context shared-p01

EOF
}

check_prerequisites() {
    local missing=0

    # Check required commands
    for cmd in kubectl az base64; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            missing=1
        fi
    done

    # Check if rbac-core directory exists
    if [[ ! -d "$RBAC_CORE_DIR" ]]; then
        log_error "RBAC core directory not found: $RBAC_CORE_DIR"
        missing=1
    fi

    # Check if rbac-core files exist
    local required_files=(
        "sa-argocd-manager.yaml"
        "cr-argocd-manager.yaml"
        "crb-argocd-manager.yaml"
        "sa-argocd-manager-token.yaml"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "${RBAC_CORE_DIR}/${file}" ]]; then
            log_error "Required file not found: ${RBAC_CORE_DIR}/${file}"
            missing=1
        fi
    done

    # Check Azure login
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Run: az login"
        missing=1
    fi

    # Check kubectl connectivity
    if [[ -n "$KUBECTL_CONTEXT" ]]; then
        if ! kubectl config use-context "$KUBECTL_CONTEXT" &> /dev/null; then
            log_error "Invalid kubectl context: $KUBECTL_CONTEXT"
            missing=1
        fi
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        log_error "Prerequisites check failed. Please fix the issues above."
        exit 1
    fi

    log_success "Prerequisites check passed"
}

deploy_rbac_resources() {
    log_info "Deploying ArgoCD manager RBAC resources..."

    if kubectl apply -f "$RBAC_CORE_DIR/" &> /dev/null; then
        log_success "RBAC resources applied successfully"
    else
        log_error "Failed to apply RBAC resources"
        return 1
    fi

    # Verify resources were created
    log_info "Verifying resources..."

    if ! kubectl get serviceaccount argocd-manager -n kube-system &> /dev/null; then
        log_error "ServiceAccount argocd-manager not found in kube-system namespace"
        return 1
    fi
    log_success "ServiceAccount: argocd-manager (kube-system)"

    if ! kubectl get clusterrole argocd-manager-role &> /dev/null; then
        log_error "ClusterRole argocd-manager-role not found"
        return 1
    fi
    log_success "ClusterRole: argocd-manager-role"

    if ! kubectl get clusterrolebinding argocd-manager &> /dev/null; then
        log_error "ClusterRoleBinding argocd-manager not found"
        return 1
    fi
    log_success "ClusterRoleBinding: argocd-manager"
}

wait_for_token_secret() {
    log_info "Waiting for token secret to be created..."

    local max_wait=60
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        if kubectl get secret argocd-manager -n kube-system &> /dev/null; then
            # Check if token data exists
            if kubectl get secret argocd-manager -n kube-system -o jsonpath='{.data.token}' 2>/dev/null | grep -q .; then
                log_success "Token secret created successfully"
                return 0
            fi
        fi

        sleep 2
        waited=$((waited + 2))
        echo -n "."
    done

    echo ""
    log_error "Timeout waiting for token secret to be created"
    return 1
}

extract_credentials() {
    local cluster_name="$1"

    log_info "Extracting cluster credentials..."

    # Extract bearer token
    TOKEN=$(kubectl get secret argocd-manager -n kube-system -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)
    if [[ -z "$TOKEN" ]]; then
        log_error "Failed to extract bearer token"
        return 1
    fi
    log_success "Bearer token extracted (${#TOKEN} characters)"

    # Extract CA certificate
    CA_DATA=$(kubectl get secret argocd-manager -n kube-system -o jsonpath='{.data.ca\.crt}' 2>/dev/null)
    if [[ -z "$CA_DATA" ]]; then
        log_error "Failed to extract CA certificate"
        return 1
    fi
    log_success "CA certificate extracted (base64 encoded)"
}

store_in_keyvault() {
    local cluster_name="$1"

    log_info "Storing credentials in Azure Key Vault: $VAULT_NAME"

    # Store token
    if az keyvault secret set \
        --vault-name "$VAULT_NAME" \
        --name "argocd-cluster-${cluster_name}-token" \
        --value "$TOKEN" \
        --output none 2>/dev/null; then
        log_success "Stored: argocd-cluster-${cluster_name}-token"
    else
        log_error "Failed to store token in Key Vault"
        return 1
    fi

    # Store CA certificate
    if az keyvault secret set \
        --vault-name "$VAULT_NAME" \
        --name "argocd-cluster-${cluster_name}-ca" \
        --value "$CA_DATA" \
        --output none 2>/dev/null; then
        log_success "Stored: argocd-cluster-${cluster_name}-ca"
    else
        log_error "Failed to store CA certificate in Key Vault"
        return 1
    fi
}

verify_keyvault_secrets() {
    local cluster_name="$1"

    log_info "Verifying Key Vault secrets..."

    local secrets=(
        "argocd-cluster-${cluster_name}-token"
        "argocd-cluster-${cluster_name}-ca"
    )

    for secret in "${secrets[@]}"; do
        if az keyvault secret show \
            --vault-name "$VAULT_NAME" \
            --name "$secret" \
            --query "id" \
            --output tsv &> /dev/null; then
            log_success "Verified: $secret"
        else
            log_warning "Could not verify: $secret"
        fi
    done
}

print_summary() {
    local cluster_name="$1"
    local context_name="$2"

    cat << EOF

${GREEN}═══════════════════════════════════════════════════════════════════${NC}
${GREEN}  Cluster Registration Complete${NC}
${GREEN}═══════════════════════════════════════════════════════════════════${NC}

  Cluster Name:    ${BLUE}${cluster_name}${NC}
  Kubectl Context: ${BLUE}${context_name}${NC}
  Key Vault:       ${BLUE}${VAULT_NAME}${NC}

${YELLOW}Next Steps:${NC}

  1. Create an ExternalSecret manifest for this cluster:
     ${BLUE}templates/argocd/secrets/es-cluster-${cluster_name}.yaml${NC}

  2. Deploy the ExternalSecret to the ArgoCD cluster:
     ${BLUE}kubectl apply -f deployments/platform-prod01/argocd/secrets/es-cluster-${cluster_name}.yaml${NC}

  3. Verify the secret is synced:
     ${BLUE}kubectl get externalsecret es-cluster-${cluster_name} -n platform-argocd${NC}

  4. Check ArgoCD recognized the cluster:
     ${BLUE}kubectl get secret cluster-${cluster_name} -n platform-argocd${NC}

EOF
}

###############################################################################
# Main
###############################################################################

main() {
    # Parse arguments
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        usage
        exit 0
    fi

    CLUSTER_NAME="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vault-name)
                VAULT_NAME="$2"
                shift 2
                ;;
            --context)
                KUBECTL_CONTEXT="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate cluster name
    if [[ ! "$CLUSTER_NAME" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        log_error "Invalid cluster name: $CLUSTER_NAME"
        log_error "Cluster name must be lowercase alphanumeric with hyphens"
        exit 1
    fi

    # Get current context name for display
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")

    # Print configuration
    log_info "Cluster Registration Configuration"
    echo "  Cluster Name:    $CLUSTER_NAME"
    echo "  Kubectl Context: ${KUBECTL_CONTEXT:-$CURRENT_CONTEXT (current)}"
    echo "  Key Vault:       $VAULT_NAME"
    echo ""

    # Confirm with user
    read -p "Continue with cluster registration? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Registration cancelled by user"
        exit 0
    fi

    # Execute registration steps
    check_prerequisites

    if [[ -n "$KUBECTL_CONTEXT" ]]; then
        log_info "Switching to context: $KUBECTL_CONTEXT"
        kubectl config use-context "$KUBECTL_CONTEXT"
    fi

    deploy_rbac_resources || exit 1
    wait_for_token_secret || exit 1
    extract_credentials "$CLUSTER_NAME" || exit 1
    store_in_keyvault "$CLUSTER_NAME" || exit 1
    verify_keyvault_secrets "$CLUSTER_NAME"

    print_summary "$CLUSTER_NAME" "${KUBECTL_CONTEXT:-$CURRENT_CONTEXT}"

    log_success "Cluster registration completed successfully!"
}

main "$@"
