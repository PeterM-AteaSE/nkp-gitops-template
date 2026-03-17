#!/bin/bash
# Script to create ArgoCD cluster secret using External Secrets Operator
# This script extracts cluster credentials from kubeconfig and stores them in Azure Key Vault
# Supports both token-based and certificate-based authentication
#
# Usage: ./create-cluster-secret.sh <cluster-name> <context-name> [project] [auth-type]
#
# auth-type: token (default) or cert
#
# Example: ./create-cluster-secret.sh platform-prod01 platform-prod01-admin platform token

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VAULT_NAME="<AZURE_KEY_VAULT_NAME>"
ARGOCD_NAMESPACE="platform-argocd"
SECRETSTORE_NAME="eso-store-platform"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required commands exist
check_dependencies() {
    local missing_deps=()
    
    for cmd in kubectl az jq; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required commands: ${missing_deps[*]}"
        echo "Please install missing dependencies and try again."
        exit 1
    fi
}

# Function to validate inputs
validate_inputs() {
    if [ -z "$CLUSTER_NAME" ]; then
        print_error "Cluster name is required"
        echo "Usage: $0 <cluster-name> <context-name> [project] [auth-type]"
        exit 1
    fi
    
    if [ -z "$CONTEXT_NAME" ]; then
        print_error "Context name is required"
        echo "Usage: $0 <cluster-name> <context-name> [project] [auth-type]"
        exit 1
    fi
    
    if [ "$AUTH_TYPE" != "token" ] && [ "$AUTH_TYPE" != "cert" ]; then
        print_error "Invalid auth-type. Must be 'token' or 'cert'"
        exit 1
    fi
    
    # Check if context exists
    if ! kubectl config get-contexts "$CONTEXT_NAME" &> /dev/null; then
        print_error "Context '$CONTEXT_NAME' not found in kubeconfig"
        echo "Available contexts:"
        kubectl config get-contexts -o name
        exit 1
    fi
}

# Function to extract cluster credentials
extract_credentials() {
    print_info "Extracting cluster credentials from kubeconfig..."
    print_info "Authentication type: $AUTH_TYPE"
    
    SERVER_URL=$(kubectl config view --context="$CONTEXT_NAME" --minify -o jsonpath='{.clusters[0].cluster.server}')
    CA_DATA=$(kubectl config view --context="$CONTEXT_NAME" --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
    
    # Validate extracted data
    if [ -z "$SERVER_URL" ]; then
        print_error "Could not extract server URL from context"
        exit 1
    fi
    
    if [ -z "$CA_DATA" ]; then
        print_error "Could not extract CA certificate from context"
        exit 1
    fi
    
    if [ "$AUTH_TYPE" = "token" ]; then
        # Extract bearer token
        BEARER_TOKEN=$(kubectl config view --context="$CONTEXT_NAME" --minify --raw -o jsonpath='{.users[0].user.token}')
        if [ -z "$BEARER_TOKEN" ]; then
            print_error "Could not extract bearer token from context"
            print_warn "Make sure your kubeconfig uses token-based authentication"
            exit 1
        fi
        print_info "Bearer token extracted successfully"
    else
        # Extract certificates
        CERT_DATA=$(kubectl config view --context="$CONTEXT_NAME" --minify --raw -o jsonpath='{.users[0].user.client-certificate-data}')
        KEY_DATA=$(kubectl config view --context="$CONTEXT_NAME" --minify --raw -o jsonpath='{.users[0].user.client-key-data}')
        if [ -z "$CERT_DATA" ] || [ -z "$KEY_DATA" ]; then
            print_error "Could not extract certificate data from context"
            print_warn "Make sure your kubeconfig uses certificate-based authentication"
            exit 1
        fi
        print_info "Client certificates extracted successfully"
    fi
    
    print_info "Server URL: $SERVER_URL"
}

# Function to store secrets in Azure Key Vault
store_in_keyvault() {
    print_info "Storing credentials in Azure Key Vault: $VAULT_NAME"
    
    # Check if already logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure"
        echo "Please run: az login"
        exit 1
    fi
    
    # Store secrets based on auth type
    if [ "$AUTH_TYPE" = "token" ]; then
        print_info "Storing bearer token..."
        az keyvault secret set \
            --vault-name "$VAULT_NAME" \
            --name "argocd-cluster-${CLUSTER_NAME}-token" \
            --value "$BEARER_TOKEN" \
            --output none
    else
        print_info "Storing client certificate..."
        az keyvault secret set \
            --vault-name "$VAULT_NAME" \
            --name "argocd-cluster-${CLUSTER_NAME}-cert" \
            --value "$CERT_DATA" \
            --output none
        
        print_info "Storing client key..."
        az keyvault secret set \
            --vault-name "$VAULT_NAME" \
            --name "argocd-cluster-${CLUSTER_NAME}-key" \
            --value "$KEY_DATA" \
            --output none
    fi
    
    print_info "Storing CA certificate..."
    az keyvault secret set \
        --vault-name "$VAULT_NAME" \
        --name "argocd-cluster-${CLUSTER_NAME}-ca" \
        --value "$CA_DATA" \
        --output none
    
    print_info "Credentials stored in Key Vault successfully"
}

# Function to create ExternalSecret manifest
create_externalsecret() {
    local output_file="es-cluster-${CLUSTER_NAME}.yaml"
    
    print_info "Creating ExternalSecret manifest: $output_file"
    
    if [ "$AUTH_TYPE" = "token" ]; then
        cat > "$output_file" <<EOF
---
# ArgoCD Cluster Secret for: ${CLUSTER_NAME}
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Context: ${CONTEXT_NAME}
# Auth Type: Bearer Token
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: es-cluster-${CLUSTER_NAME}
  namespace: ${ARGOCD_NAMESPACE}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: ${SECRETSTORE_NAME}
    kind: SecretStore
  target:
    name: cluster-${CLUSTER_NAME}
    creationPolicy: Owner
    template:
      metadata:
        labels:
          argocd.argoproj.io/secret-type: cluster
      type: Opaque
      data:
        name: ${CLUSTER_NAME}
        server: ${SERVER_URL}
        project: ${PROJECT}
        config: |
          {
            "bearerToken": "{{ .bearerToken }}",
            "tlsClientConfig": {
              "insecure": false,
              "caData": "{{ .caData }}"
            }
          }
  data:
    - secretKey: bearerToken
      remoteRef:
        key: argocd-cluster-${CLUSTER_NAME}-token
    - secretKey: caData
      remoteRef:
        key: argocd-cluster-${CLUSTER_NAME}-ca
EOF
    else
        cat > "$output_file" <<EOF
---
# ArgoCD Cluster Secret for: ${CLUSTER_NAME}
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Context: ${CONTEXT_NAME}
# Auth Type: Client Certificate
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: es-cluster-${CLUSTER_NAME}
  namespace: ${ARGOCD_NAMESPACE}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: ${SECRETSTORE_NAME}
    kind: SecretStore
  target:
    name: cluster-${CLUSTER_NAME}
    creationPolicy: Owner
    template:
      metadata:
        labels:
          argocd.argoproj.io/secret-type: cluster
      type: Opaque
      data:
        name: ${CLUSTER_NAME}
        server: ${SERVER_URL}
        project: ${PROJECT}
        config: |
          {
            "tlsClientConfig": {
              "insecure": false,
              "certData": "{{ .certData }}",
              "keyData": "{{ .keyData }}",
              "caData": "{{ .caData }}"
            }
          }
  data:
    - secretKey: certData
      remoteRef:
        key: argocd-cluster-${CLUSTER_NAME}-cert
    - secretKey: keyData
      remoteRef:
        key: argocd-cluster-${CLUSTER_NAME}-key
    - secretKey: caData
      remoteRef:
        key: argocd-cluster-${CLUSTER_NAME}-ca
EOF
    fi
    
    print_info "ExternalSecret manifest created: $output_file"
}

# Function to apply the ExternalSecret
apply_externalsecret() {
    local output_file="es-cluster-${CLUSTER_NAME}.yaml"
    
    print_info "Applying ExternalSecret to cluster..."
    
    if kubectl apply -f "$output_file"; then
        print_info "ExternalSecret applied successfully"
        
        # Wait for secret to be created
        print_info "Waiting for secret to be created (timeout: 30s)..."
        if kubectl wait --for=condition=Ready externalsecret/es-cluster-${CLUSTER_NAME} \
            -n ${ARGOCD_NAMESPACE} --timeout=30s 2>/dev/null; then
            print_info "Secret created successfully!"
            
            # Verify the secret
            if kubectl get secret cluster-${CLUSTER_NAME} -n ${ARGOCD_NAMESPACE} &> /dev/null; then
                print_info "✓ Secret 'cluster-${CLUSTER_NAME}' exists in namespace '${ARGOCD_NAMESPACE}'"
                
                # Show the secret keys
                echo ""
                echo "Secret contents:"
                kubectl get secret cluster-${CLUSTER_NAME} -n ${ARGOCD_NAMESPACE} -o json | \
                    jq -r '.data | keys[]' | sed 's/^/  - /'
            fi
        else
            print_warn "Secret creation timed out or failed"
            echo "Check the ExternalSecret status with:"
            echo "  kubectl describe externalsecret es-cluster-${CLUSTER_NAME} -n ${ARGOCD_NAMESPACE}"
        fi
    else
        print_error "Failed to apply ExternalSecret"
        exit 1
    fi
}

# Function to show summary
show_summary() {
    echo ""
    echo "======================================"
    echo "Summary"
    echo "======================================"
    echo "Cluster Name:     $CLUSTER_NAME"
    echo "Server URL:       $SERVER_URL"
    echo "Project:          $PROJECT"
    echo "ArgoCD Namespace: $ARGOCD_NAMESPACE"
    echo ""
    echo "Key Vault Secrets Created:"
    if [ "$AUTH_TYPE" = "token" ]; then
        echo "  - argocd-cluster-${CLUSTER_NAME}-token"
        echo "  - argocd-cluster-${CLUSTER_NAME}-ca"
    else
        echo "  - argocd-cluster-${CLUSTER_NAME}-cert"
        echo "  - argocd-cluster-${CLUSTER_NAME}-key"
        echo "  - argocd-cluster-${CLUSTER_NAME}-ca"
    fi
    echo ""
    echo "ExternalSecret:   es-cluster-${CLUSTER_NAME}"
    echo "Secret Created:   cluster-${CLUSTER_NAME}"
    echo ""
    echo "Next Steps:"
    echo "  1. Verify cluster appears in ArgoCD UI"
    echo "  2. Check ExternalSecret status:"
    echo "     kubectl get externalsecret -n ${ARGOCD_NAMESPACE}"
    echo "  3. View cluster in ArgoCD:"
    echo "     kubectl exec -n ${ARGOCD_NAMESPACE} <argocd-pod> -- argocd cluster list"
    echo ""
}

# Main execution
main() {
    echo "======================================"
    echo "ArgoCD Cluster Secret Creator"
    echo "======================================"
    echo ""
    
    # Parse arguments
    CLUSTER_NAME="$1"
    CONTEXT_NAME="$2"
    PROJECT="${3:-default}"
    AUTH_TYPE="${4:-token}"
    
    # Run checks
    check_dependencies
    validate_inputs
    
    # Extract and store credentials
    extract_credentials
    store_in_keyvault
    
    # Create and apply ExternalSecret
    create_externalsecret
    
    # Ask for confirmation before applying
    echo ""
    read -p "Apply ExternalSecret to cluster? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apply_externalsecret
        show_summary
    else
        print_info "Skipped applying ExternalSecret"
        echo "To apply manually:"
        echo "  kubectl apply -f es-cluster-${CLUSTER_NAME}.yaml"
    fi
}

# Run main function
main "$@"
