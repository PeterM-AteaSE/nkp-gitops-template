# ArgoCD Cluster Registration with External Secrets

## Executive Summary

This solution enables secure ArgoCD cluster registration using External Secrets Operator (ESO) and Azure Key Vault. Cluster credentials (certificates and keys) are stored securely in Azure Key Vault and automatically synced to ArgoCD without storing sensitive data in Git.

## Solution Overview

### Traditional Approach (Not Recommended)
```
Git Repository → Kubernetes Secret (with hardcoded certificates)
```
❌ Sensitive data in Git  
❌ Difficult to rotate credentials  
❌ Security audit concerns  

### ESO Approach (Recommended)
```
Azure Key Vault → External Secrets Operator → Kubernetes Secret → ArgoCD
```
✅ No sensitive data in Git  
✅ Easy credential rotation  
✅ Centralized secret management  
✅ Automated sync with 1-hour refresh  
✅ Audit logging in Azure  

## Implementation Approach

We use **Approach 1 from the External Secrets JSON Guide**: Template JSON from Multiple Key Vault Secrets.

### Why This Approach?

1. **Fine-grained Control**: Each credential (cert, key, CA) is a separate Key Vault secret
2. **Easy Updates**: Rotate individual credentials without touching others
3. **Clear Visibility**: See exactly which secrets are being used
4. **Flexible**: Mix static config (server URL, name) with dynamic secrets (certificates)

## Architecture

```
┌──────────────────────────────────┐
│  Developer/Admin                 │
│  Runs: create-cluster-secret.sh  │
└────────────┬─────────────────────┘
             │
             ▼
┌──────────────────────────────────┐
│  Azure Key Vault                 │
│  <AZURE_KEY_VAULT_NAME>                │
│                                  │
│  Stores:                         │
│  • argocd-cluster-X-cert         │
│  • argocd-cluster-X-key          │
│  • argocd-cluster-X-ca           │
└────────────┬─────────────────────┘
             │
             │ ESO Fetches (every 1h)
             ▼
┌──────────────────────────────────┐
│  ExternalSecret                  │
│  es-cluster-X                    │
│  (in Git, no sensitive data)     │
└────────────┬─────────────────────┘
             │
             │ Creates/Updates
             ▼
┌──────────────────────────────────┐
│  Kubernetes Secret               │
│  cluster-X                       │
│  label: cluster                  │
│                                  │
│  Contains JSON with TLS config   │
└────────────┬─────────────────────┘
             │
             │ ArgoCD Watches
             ▼
┌──────────────────────────────────┐
│  ArgoCD                          │
│  Registers & Manages Cluster     │
└──────────────────────────────────┘
```

## Files Created

### 1. Template File
**Location**: `/templates/argocd/secrets/es-argocd-cluster.yaml`

Generic template showing the structure. Copy and customize for each cluster.

**Key Features**:
- Uses External Secrets Operator
- Fetches from Azure Key Vault (`eso-store-platform`)
- Templates JSON config with TLS credentials
- Sets proper ArgoCD labels

### 2. Automation Script
**Location**: `/templates/argocd/secrets/create-cluster-secret.sh`

Automated script that:
1. Extracts credentials from your kubeconfig
2. Stores them in Azure Key Vault
3. Creates the ExternalSecret manifest
4. Optionally applies it to the cluster

**Usage**:
```bash
./create-cluster-secret.sh <cluster-name> <context-name> [project]
```

**Example**:
```bash
./create-cluster-secret.sh tanzu-wld05 tanzu-wld05-admin@tanzu-wld05 platform
```

### 3. Documentation
**Location**: `/templates/argocd/secrets/CLUSTER_SECRETS_README.md`

Complete documentation including:
- Step-by-step manual process
- Example workflows
- Troubleshooting guide
- Security considerations

### 4. External Secrets JSON Guide
**Location**: `/EXTERNAL_SECRETS_JSON_GUIDE.md`

Comprehensive guide covering:
- 5 different ESO approaches
- Decision matrix
- Advanced templating
- Testing and troubleshooting

## Quick Start

### Option 1: Automated (Recommended)

```bash
cd templates/argocd/secrets

# For token-based authentication (default)
./create-cluster-secret.sh platform-prod01 platform-prod01-admin default token

# For certificate-based authentication
./create-cluster-secret.sh my-cluster my-k8s-context platform cert

# Script will:
# ✓ Extract credentials from kubeconfig
# ✓ Store in Azure Key Vault
# ✓ Create ExternalSecret manifest
# ✓ Apply to cluster (with confirmation)
```

### Option 2: Manual

#### For Token-Based Authentication:

```bash
# 1. Extract from kubeconfig
kubectl config view --context=platform-prod01-admin --minify --raw -o jsonpath='{.users[0].user.token}'

# 2. Store in Key Vault
az keyvault secret set --vault-name <AZURE_KEY_VAULT_NAME> \
  --name argocd-cluster-platform-prod01-token --value "<token>"

az keyvault secret set --vault-name <AZURE_KEY_VAULT_NAME> \
  --name argocd-cluster-platform-prod01-ca --value "<ca-data>"

# 3. Copy and customize template
cp es-argocd-cluster.yaml es-cluster-platform-prod01.yaml
# Edit: name, server URL, project, auth config

# 4. Apply
kubectl apply -f es-cluster-platform-prod01.yaml -n platform-argocd
```

#### For Certificate-Based Authentication:

```bash
# 1. Extract from kubeconfig
kubectl config view --context=my-context --minify --raw -o jsonpath='{.users[0].user.client-certificate-data}'

# 2. Store in Key Vault
az keyvault secret set --vault-name <AZURE_KEY_VAULT_NAME> \
  --name argocd-cluster-my-cluster-cert --value "<cert-data>"
# (also store key and CA)

# 3. Copy and customize template
cp es-argocd-cluster.yaml es-cluster-my-cluster.yaml
# Edit: name, server URL, project, Key Vault secret names

# 4. Apply
kubectl apply -f es-cluster-my-cluster.yaml -n platform-argocd
```

## Example: Real Cluster Registration

Based on your environment (platform-prod01 with token-based authentication):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: es-cluster-platform-prod01
  namespace: platform-argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: eso-store-platform
    kind: SecretStore
  target:
    name: cluster-platform-prod01
    creationPolicy: Owner
    template:
      metadata:
        labels:
          argocd.argoproj.io/secret-type: cluster
      type: Opaque
      data:
        name: platform-prod01
        server: https://10.192.22.5:6443
        project: default
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
        key: argocd-cluster-platform-prod01-token
    - secretKey: caData
      remoteRef:
        key: argocd-cluster-platform-prod01-ca
```

This creates the exact same secret structure, but credentials come from Azure Key Vault!

## Benefits for Customer

### Security
- ✅ **No secrets in Git**: Credentials stored only in Azure Key Vault
- ✅ **Audit trail**: Azure tracks all Key Vault access
- ✅ **Least privilege**: ESO service principal has minimal permissions
- ✅ **Encryption**: At rest in Key Vault and Kubernetes etcd

### Operations
- ✅ **Easy rotation**: Update Key Vault, ESO syncs automatically
- ✅ **Centralized management**: One Key Vault for all clusters
- ✅ **Automated sync**: Checks for changes every hour
- ✅ **GitOps friendly**: ExternalSecret manifests in Git (no secrets!)

### Developer Experience
- ✅ **Simple script**: One command to register a cluster
- ✅ **Standard process**: Same approach for all clusters
- ✅ **Self-service**: Developers can register clusters (with proper RBAC)
- ✅ **Clear documentation**: Step-by-step guides available

## Credential Rotation Process

When tokens expire or certificates need rotation:

### For Token-Based Authentication:

```bash
# 1. Update Key Vault with new token
az keyvault secret set --vault-name <AZURE_KEY_VAULT_NAME> \
  --name argocd-cluster-platform-prod01-token --value "<new-token>"

# 2. Wait for ESO to sync (max 1 hour)
# Or force immediate sync:
kubectl delete secret cluster-platform-prod01 -n platform-argocd

# 3. Verify
kubectl get secret cluster-platform-prod01 -n platform-argocd
```

### For Certificate-Based Authentication:

```bash
# 1. Update Key Vault with new credentials
az keyvault secret set --vault-name <AZURE_KEY_VAULT_NAME> \
  --name argocd-cluster-my-cluster-cert --value "<new-cert>"

# 2. ESO syncs automatically
# Or force: kubectl delete secret cluster-my-cluster -n platform-argocd
```

No Git commits required! 🎉

## Cost Considerations

- Azure Key Vault operations are minimal (read once per hour per cluster)
- ESO is open source (no licensing costs)
- Standard Kubernetes resources (no additional infrastructure)

## Next Steps - Customer Discussion

### Questions to Ask:

1. **How many clusters need to be registered?**
   - Determines number of secrets in Key Vault

2. **Certificate rotation frequency?**
   - Standard: Annually
   - Our solution: Update Key Vault, automatic propagation

3. **Who manages cluster registration?**
   - Platform team only?
   - Developer self-service?
   - Determines RBAC setup

4. **Existing Key Vault setup?**
   - We use: `<AZURE_KEY_VAULT_NAME>`
   - Networking/access already configured?

5. **Testing requirements?**
   - Can we test with one non-production cluster first?

### Demonstration Plan:

1. **Show the flow** (5 min)
   - Display architecture diagram
   - Explain Key Vault → ESO → Secret → ArgoCD

2. **Live demo** (10 min)
   - Run `create-cluster-secret.sh` script
   - Show ExternalSecret creation
   - Verify secret in cluster
   - Show cluster appears in ArgoCD

3. **Security discussion** (5 min)
   - No secrets in Git
   - Audit logging
   - Rotation process

4. **Q&A and decision** (10 min)
   - Address concerns
   - Get approval to proceed

## Implementation Timeline

- **Week 1**: Test with 1-2 non-production clusters
- **Week 2**: Document and refine process
- **Week 3**: Register production clusters
- **Week 4**: Knowledge transfer and handover

## Support & Documentation

All documentation included:
- `/EXTERNAL_SECRETS_JSON_GUIDE.md` - Comprehensive ESO guide
- `/templates/argocd/secrets/CLUSTER_SECRETS_README.md` - Cluster registration guide
- `/templates/argocd/secrets/es-argocd-cluster.yaml` - Template file
- `/templates/argocd/secrets/create-cluster-secret.sh` - Automation script

## Contact

For questions or issues:
1. Check documentation in repository
2. Review troubleshooting section in README
3. Reach out to platform team

---

**Last Updated**: 2026-02-17  
**Version**: 1.0  
**Status**: Ready for customer review
