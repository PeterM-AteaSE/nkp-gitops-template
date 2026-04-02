# Bootstrapping External Secrets Operator (ESO)

## Overview

External Secrets Operator synchronizes secrets from Azure Key Vault to Kubernetes secrets. This is essential for managing sensitive credentials like OIDC client secrets, cluster authentication tokens, and API keys.

## Prerequisites

1. **kubectl** configured with access to target cluster
2. **Azure CLI** installed and authenticated (`az login`)
3. **git <CUSTOMER_SHORT_UPPER>-argocd-gitops** cloned locally and updated to latest version
4. **Access to Azure Key Vault**: `<AZURE_KEY_VAULT_NAME>`

## Bootstrapping Process

### 1. Set Cluster Context

```bash
# For platform-prod01
kubectl config use-context platform-prod01

# Or use short name if you've run rename-contexts.sh
kubectl config use-context platform-p01
```

### 2. Create Namespace

```bash
kubectl create ns platform-eso
```

### 3. Deploy External Secrets Operator

```bash
# From the git repo root directory
# Note: Using --server-side to avoid annotation size limits with large manifests
kubectl -n platform-eso apply --server-side -f deployments/platform-prod01/external-secrets-operator/install/install.yaml
```

### 4. Wait for ESO to be Ready

```bash
# Wait for CRDs to be available
kubectl wait --for condition=established --timeout=60s \
  crd/externalsecrets.external-secrets.io \
  crd/secretstores.external-secrets.io \
  crd/clustersecretstores.external-secrets.io

# Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=external-secrets \
  -n platform-eso --timeout=120s
```

### 5. Create Bootstrap Secret for Azure Key Vault Access

ESO needs credentials to access Azure Key Vault. Create the bootstrap secret:

```bash
# From the git repo root directory
./utils/bootstrap-secrets-platform-kv.sh
```

This script will:
- Prompt for Azure Service Principal credentials (Client ID and Secret)
- Create a Kubernetes secret in the `platform-eso` namespace
- This secret is used by SecretStores to authenticate to Azure Key Vault

**Note:** The Service Principal must have `Get` permissions on secrets in `<AZURE_KEY_VAULT_NAME>`.

### 6. Verify Installation

```bash
# Check ESO pods
kubectl get pods -n platform-eso

# Expected output:
# NAME                                               READY   STATUS    RESTARTS   AGE
# external-secrets-xxxxxxxxxx-xxxxx                  1/1     Running   0          2m
# external-secrets-cert-controller-xxxxxxxxxx-xxxxx  1/1     Running   0          2m
# external-secrets-webhook-xxxxxxxxxx-xxxxx          1/1     Running   0          2m

# Check CRDs
kubectl get crd | grep external-secrets

# Expected output:
# clustersecretstores.external-secrets.io
# externalsecrets.external-secrets.io
# secretstores.external-secrets.io
```

## Using External Secrets

Once ESO is installed, you can create SecretStores and ExternalSecrets:

### Example: Create a SecretStore

```bash
# Deploy a SecretStore that references Azure Key Vault
kubectl apply -f deployments/platform-prod01/argocd/eso/eso-store-platform.yaml
```

### Example: Create an ExternalSecret

```bash
# Create an ExternalSecret for ArgoCD OIDC credentials
kubectl apply -f deployments/platform-prod01/argocd/secrets/es-argocd-oidc.yaml

# Wait for the secret to be created
kubectl wait --for=condition=ready externalsecret/es-argocd-oidc \
  -n platform-argocd --timeout=60s

# Verify the secret was created
kubectl get secret argocd-oidc -n platform-argocd
```

## Advanced Usage

For advanced scenarios like creating secrets with JSON documents, see:
- [External Secrets JSON Guide](../EXTERNAL_SECRETS_JSON_GUIDE.md) - Complete guide with 5 different approaches

For ArgoCD cluster registration with External Secrets:
- [ArgoCD Cluster Registration Proposal](../ARGOCD_CLUSTER_REGISTRATION_PROPOSAL.md)
- [Cluster Secrets README](../templates/argocd/secrets/CLUSTER_SECRETS_README.md)

## Troubleshooting

### ExternalSecret shows "SecretSyncError"

```bash
# Check ExternalSecret details
kubectl describe externalsecret <name> -n <namespace>

# Check ESO logs
kubectl logs -n platform-eso -l app.kubernetes.io/name=external-secrets

# Common causes:
# - Service Principal lacks permissions on Key Vault
# - Secret name doesn't exist in Key Vault
# - SecretStore not properly configured
```

### Secret not updating after Key Vault change

```bash
# Force refresh by deleting the secret
kubectl delete secret <secret-name> -n <namespace>

# ESO will recreate it with the latest value from Key Vault
```

### Check SecretStore status

```bash
kubectl get secretstore -n <namespace>
kubectl describe secretstore <name> -n <namespace>
```

## Next Steps

After ESO is installed and working:
1. Deploy ArgoCD (see [bootstrap/ArgoCD.md](ArgoCD.md))
2. Register managed clusters with ArgoCD (see [Cluster Secrets README](../templates/argocd/secrets/CLUSTER_SECRETS_README.md))
3. Configure other applications that need secrets from Azure Key Vault
