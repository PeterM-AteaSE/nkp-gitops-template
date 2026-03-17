# ArgoCD Cluster Secret Templates

This directory contains templates for registering Kubernetes clusters in ArgoCD using External Secrets Operator.

## Overview

ArgoCD needs cluster secrets to authenticate and deploy applications to managed clusters. Instead of storing sensitive certificate data directly in Git, we use External Secrets Operator to fetch credentials from Azure Key Vault.

## Files

- `es-argocd-cluster.yaml` - Template for creating ArgoCD cluster secrets

## Prerequisites

1. **External Secrets Operator** installed and configured
2. **SecretStore** configured for Azure Key Vault (`eso-store-platform`)
3. **Cluster credentials** stored in Azure Key Vault

## Authentication Methods Supported

### Token-Based Authentication (Recommended)
Uses a bearer token for authentication. Common in managed Kubernetes services and service account scenarios.

**Required Key Vault Secrets:**
- `argocd-cluster-<cluster-name>-token` (bearer token)
- `argocd-cluster-<cluster-name>-ca` (CA certificate)

### Certificate-Based Authentication
Uses client certificates for mutual TLS authentication.

**Required Key Vault Secrets:**
- `argocd-cluster-<cluster-name>-cert` (client certificate)
- `argocd-cluster-<cluster-name>-key` (client private key)
- `argocd-cluster-<cluster-name>-ca` (CA certificate)

## How to Register a New Cluster

### Step 1: Extract Cluster Credentials

From your kubeconfig file, extract the cluster credentials:

#### For Token-Based Authentication:

```bash
# Set your cluster context name
CLUSTER_NAME="platform-prod01"
CONTEXT_NAME="platform-prod01-admin"

# Extract server URL
kubectl config view --context=$CONTEXT_NAME --minify -o jsonpath='{.clusters[0].cluster.server}'

# Extract bearer token
kubectl config view --context=$CONTEXT_NAME --minify --raw -o jsonpath='{.users[0].user.token}'

# Extract CA certificate (already base64 encoded)
kubectl config view --context=$CONTEXT_NAME --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
```

#### For Certificate-Based Authentication:

```bash
# Set your cluster context name
CLUSTER_NAME="my-cluster"
CONTEXT_NAME="your-context-name"

# Extract server URL
kubectl config view --context=$CONTEXT_NAME --minify -o jsonpath='{.clusters[0].cluster.server}'

# Extract client certificate (already base64 encoded)
kubectl config view --context=$CONTEXT_NAME --minify --raw -o jsonpath='{.users[0].user.client-certificate-data}'

# Extract client key (already base64 encoded)
kubectl config view --context=$CONTEXT_NAME --minify --raw -o jsonpath='{.users[0].user.client-key-data}'

# Extract CA certificate (already base64 encoded)
kubectl config view --context=$CONTEXT_NAME --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
```

### Step 2: Store Credentials in Azure Key Vault

Store the extracted credentials in Azure Key Vault with the appropriate naming convention:

#### For Token-Based Authentication:

```bash
CLUSTER_NAME="platform-prod01"
VAULT_NAME="<AZURE_KEY_VAULT_NAME>"

# Store bearer token
az keyvault secret set \
  --vault-name $VAULT_NAME \
  --name "argocd-cluster-${CLUSTER_NAME}-token" \
  --value "<paste-bearer-token>"

# Store CA certificate
az keyvault secret set \
  --vault-name $VAULT_NAME \
  --name "argocd-cluster-${CLUSTER_NAME}-ca" \
  --value "<paste-ca-certificate-data>"
```

#### For Certificate-Based Authentication:

```bash
CLUSTER_NAME="my-cluster"
VAULT_NAME="<AZURE_KEY_VAULT_NAME>"

# Store client certificate
az keyvault secret set \
  --vault-name $VAULT_NAME \
  --name "argocd-cluster-${CLUSTER_NAME}-cert" \
  --value "<paste-client-certificate-data>"

# Store client key
az keyvault secret set \
  --vault-name $VAULT_NAME \
  --name "argocd-cluster-${CLUSTER_NAME}-key" \
  --value "<paste-client-key-data>"

# Store CA certificate
az keyvault secret set \
  --vault-name $VAULT_NAME \
  --name "argocd-cluster-${CLUSTER_NAME}-ca" \
  --value "<paste-ca-certificate-data>"
```

**Important:** The values should already be base64 encoded from the kubeconfig extraction.

### Step 3: Create ExternalSecret from Template

Copy and customize the template:

```bash
CLUSTER_NAME="platform-prod01"
SERVER_URL="https://10.192.22.5:6443"
PROJECT="default"
AUTH_TYPE="token"  # or "cert" for certificate-based

# Copy template
cp es-argocd-cluster.yaml es-cluster-${CLUSTER_NAME}.yaml

# Edit the file and update:
# - metadata.name: es-cluster-${CLUSTER_NAME}
# - target.name: cluster-${CLUSTER_NAME}
# - data.name: ${CLUSTER_NAME}
# - data.server: ${SERVER_URL}
# - data.project: ${PROJECT}
# - config section based on AUTH_TYPE (token or cert)
# - All remoteRef.key values to match your Key Vault secret names
```

### Step 4: Apply to ArgoCD Namespace

```bash
kubectl apply -f es-cluster-${CLUSTER_NAME}.yaml -n platform-argocd
```

### Step 5: Verify

```bash
# Check ExternalSecret status
kubectl get externalsecret -n platform-argocd

# Check if the secret was created
kubectl get secret cluster-${CLUSTER_NAME} -n platform-argocd

# Verify ArgoCD can see the cluster
kubectl exec -n platform-argocd <argocd-server-pod> -- argocd cluster list
```

## Example: Complete Workflow (Token-Based)

```bash
#!/bin/bash

# Configuration
CLUSTER_NAME="platform-prod01"
CONTEXT_NAME="platform-prod01-admin"
SERVER_URL="https://10.192.22.5:6443"
PROJECT="default"
VAULT_NAME="<AZURE_KEY_VAULT_NAME>"

# Extract credentials
echo "Extracting cluster credentials..."
BEARER_TOKEN=$(kubectl config view --context=$CONTEXT_NAME --minify --raw -o jsonpath='{.users[0].user.token}')
CA_DATA=$(kubectl config view --context=$CONTEXT_NAME --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# Store in Azure Key Vault
echo "Storing credentials in Azure Key Vault..."
az keyvault secret set --vault-name $VAULT_NAME --name "argocd-cluster-${CLUSTER_NAME}-token" --value "$BEARER_TOKEN"
az keyvault secret set --vault-name $VAULT_NAME --name "argocd-cluster-${CLUSTER_NAME}-ca" --value "$CA_DATA"

# Create ExternalSecret
echo "Creating ExternalSecret..."
cat > es-cluster-${CLUSTER_NAME}.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: es-cluster-${CLUSTER_NAME}
  namespace: platform-argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: eso-store-platform
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

echo "Done! Apply with: kubectl apply -f es-cluster-${CLUSTER_NAME}.yaml"
```

## Architecture

```
┌─────────────────────────┐
│ Azure Key Vault         │
│ <AZURE_KEY_VAULT_NAME>        │
│                         │
│ - cluster-demo1-cert    │
│ - cluster-demo1-key     │
│ - cluster-demo1-ca      │
└──────────┬──────────────┘
           │
           │ ESO fetches
           ▼
┌─────────────────────────┐
│ ExternalSecret          │
│ es-cluster-demo1        │
│ (namespace: argocd)     │
└──────────┬──────────────┘
           │
           │ Creates
           ▼
┌─────────────────────────┐
│ Secret                  │
│ cluster-demo1           │
│ type: cluster           │
│                         │
│ - name: demo1           │
│ - server: https://...   │
│ - config: {json}        │
└──────────┬──────────────┘
           │
           │ ArgoCD reads
           ▼
┌─────────────────────────┐
│ ArgoCD                  │
│ Manages deployments     │
│ to demo1 cluster        │
└─────────────────────────┘
```

## Security Considerations

1. **Certificate Rotation**: Update secrets in Azure Key Vault, ESO will automatically refresh based on `refreshInterval`
2. **Least Privilege**: Ensure the ESO service principal only has `Get` permissions on Key Vault secrets
3. **Audit**: Enable Azure Key Vault audit logging to track secret access
4. **Encryption**: Secrets are encrypted at rest in Azure Key Vault and in Kubernetes etcd

## Troubleshooting

### ExternalSecret shows "SecretSyncError"

```bash
# Check ESO logs
kubectl logs -n external-secrets-operator deployment/external-secrets

# Verify SecretStore is healthy
kubectl get secretstore -n platform-argocd

# Check if secrets exist in Key Vault
az keyvault secret list --vault-name <AZURE_KEY_VAULT_NAME> --query "[?starts_with(name,'argocd-cluster-')]"
```

### ArgoCD doesn't see the cluster

```bash
# Verify the secret has the correct label
kubectl get secret cluster-demo1 -n platform-argocd -o jsonpath='{.metadata.labels}'

# Should show: argocd.argoproj.io/secret-type: cluster

# Restart ArgoCD application controller to re-scan
kubectl rollout restart deployment argocd-application-controller -n platform-argocd
```

### Certificate/Key format issues

The certificates and keys should already be base64 encoded when extracted from kubeconfig. Do NOT encode them again.

```bash
# Test if the secret is valid by decoding the config
kubectl get secret cluster-demo1 -n platform-argocd -o jsonpath='{.data.config}' | base64 -d | jq .
```

## Related Documentation

- [External Secrets JSON Guide](../../EXTERNAL_SECRETS_JSON_GUIDE.md)
- [ArgoCD Cluster Credentials](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters)
- [External Secrets Operator](https://external-secrets.io/)
