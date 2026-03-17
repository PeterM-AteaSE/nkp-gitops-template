# Bootstrapping ArgoCD

## Overview

ArgoCD provides GitOps continuous delivery for Kubernetes. This guide walks through deploying ArgoCD with OIDC authentication and registering managed clusters.

## Prerequisites

1. **kubectl** with access to the platform-prod01 cluster
2. **HBG-NKP-Gitops** git repository cloned locally and updated
3. **Azure CLI** installed and authenticated (`az login`)
4. **Access to Azure Key Vault**: `<AZURE_KEY_VAULT_NAME>`
5. **External Secrets Operator** already deployed (see [ESO.md](ESO.md))

## Bootstrapping Process

### 1. Set Cluster Context

```bash
# Set context to platform-prod01
kubectl config use-context platform-prod01

# Or use short name if renamed
kubectl config use-context platform-p01
```

### 2. Create Namespace

```bash
kubectl create ns platform-argocd
kubectl config set-context --current --namespace=platform-argocd
```

### 3. Create Bootstrap Secret for Azure Key Vault

If not already created during ESO setup:

```bash
# From git repo root directory
./utils/bootstrap-secrets-platform-kv.sh
```

### 4. Deploy ESO SecretStore

Create the SecretStore that connects to Azure Key Vault:

```bash
kubectl apply -f deployments/platform-prod01/argocd/eso/eso-store-platform.yaml

# Verify SecretStore is ready
kubectl get secretstore eso-store-platform -n platform-argocd
```

### 5. Deploy OIDC Secret via External Secret

Create the ExternalSecret for ArgoCD OIDC authentication:

```bash
kubectl apply -f deployments/platform-prod01/argocd/secrets/es-argocd-oidc.yaml

# Wait for the secret to be created
kubectl wait --for=condition=ready externalsecret/es-argocd-oidc \
  -n platform-argocd --timeout=60s

# Verify the secret was created
kubectl get secret argocd-oidc -n platform-argocd

# Expected keys: OIDC_CLIENT_ID, OIDC_CLIENT_SECRET
kubectl get secret argocd-oidc -n platform-argocd -o jsonpath='{.data}' | jq 'keys'
```

### 6. Deploy ArgoCD

Install ArgoCD using Helm-generated manifests:

```bash
# Note: Using --server-side to avoid annotation size limits with large manifests
kubectl -n platform-argocd apply --server-side -f deployments/platform-prod01/argocd/install/install.yaml

# Wait for ArgoCD pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n platform-argocd --timeout=300s
```

### 7. Deploy Platform Repository Secret

Create the ExternalSecret for the platform Git repository SSH key:

```bash
kubectl apply -f deployments/platform-prod01/argocd/projects/es-platform-repo.yaml

# Wait for secret to be created
kubectl wait --for=condition=ready externalsecret/es-platform-repo \
  -n platform-argocd --timeout=60s

# Verify
kubectl get secret platform-repo -n platform-argocd
```

### 8. Register Managed Clusters

ArgoCD needs to register each Kubernetes cluster it will manage. This requires creating a ServiceAccount with cluster-admin permissions in each cluster.

#### Option A: Automated Registration (Recommended)

Use the utility script to automate the entire registration process:

```bash
# Register a cluster (will prompt for confirmation)
./utils/register-argocd-cluster.sh platform-prod01

# Register with specific context
./utils/register-argocd-cluster.sh platform-test01 --context platform-t01

# Register with different Key Vault
./utils/register-argocd-cluster.sh shared-prod01 --vault-name <AZURE_KEY_VAULT_NAME>
```

The script will:
1. ✓ Deploy ArgoCD manager RBAC resources (rbac-core)
2. ✓ Wait for token secret creation
3. ✓ Extract bearer token and CA certificate
4. ✓ Store credentials in Azure Key Vault
5. ✓ Verify all secrets were stored successfully
6. ✓ Provide next steps for ExternalSecret deployment

**Repeat for each managed cluster:**
```bash
./utils/register-argocd-cluster.sh platform-prod01
./utils/register-argocd-cluster.sh platform-test01
./utils/register-argocd-cluster.sh shared-prod01
./utils/register-argocd-cluster.sh shared-test01
```

#### Option B: Manual Registration

**For each cluster you want ArgoCD to manage** (platform-prod01, platform-test01, shared-prod01, shared-test01):

##### Step 8.1: Deploy ArgoCD Manager ServiceAccount

```bash
# Switch to the managed cluster context
kubectl config use-context <cluster-name>

# Deploy the ArgoCD manager RBAC
kubectl apply -f templates/argocd/rbac-core/

# Verify ServiceAccount was created
kubectl get sa argocd-manager -n kube-system
kubectl get clusterrole argocd-manager-role
kubectl get clusterrolebinding argocd-manager

# Verify the token secret was created (may take a few seconds)
kubectl get secret argocd-manager -n kube-system
```

#### Step 8.2: Extract Credentials and Store in Azure Key Vault

**For each managed cluster**, extract the credentials and store them in Azure Key Vault:

```bash
# Set the cluster name
CLUSTER_NAME="platform-prod01"  # Change for each cluster
VAULT_NAME="<AZURE_KEY_VAULT_NAME>"

# Extract bearer token
TOKEN=$(kubectl get secret argocd-manager -n kube-system -o jsonpath='{.data.token}' | base64 -d)

# Extract CA certificate (already base64 encoded)
CA_DATA=$(kubectl get secret argocd-manager -n kube-system -o jsonpath='{.data.ca\.crt}')

# Store in Azure Key Vault
az keyvault secret set \
  --vault-name $VAULT_NAME \
  --name "argocd-cluster-${CLUSTER_NAME}-token" \
  --value "$TOKEN"

az keyvault secret set \
  --vault-name $VAULT_NAME \
  --name "argocd-cluster-${CLUSTER_NAME}-ca" \
  --value "$CA_DATA"

echo "✅ Credentials stored for cluster: $CLUSTER_NAME"
```

**Repeat this process for each managed cluster:**
- platform-prod01
- platform-test01
- shared-prod01
- shared-test01

---

### 9. Deploy ExternalSecrets for Cluster Registration

After registering all clusters (using either Option A or B above), deploy the ExternalSecrets that will create the cluster secrets in ArgoCD.

**Switch to the ArgoCD cluster context:**

```bash
kubectl config use-context platform-p01
```

**Deploy the cluster ExternalSecrets:**

```bash
# Deploy ExternalSecrets for each registered cluster
kubectl apply -f deployments/platform-prod01/argocd/secrets/es-argocd-platform-prod01.yaml
kubectl apply -f deployments/platform-prod01/argocd/secrets/es-cluster-platform-test01.yaml
kubectl apply -f deployments/platform-prod01/argocd/secrets/es-cluster-shared-prod01.yaml
kubectl apply -f deployments/platform-prod01/argocd/secrets/es-cluster-shared-test01.yaml

# Wait for secrets to sync
kubectl wait --for=condition=ready externalsecret -n platform-argocd --all --timeout=120s
```

### 10. Verify Cluster Registration

```bash
# Check ExternalSecret sync status
kubectl get externalsecret -n platform-argocd

# Expected output shows all secrets with READY: True
# NAME                          STORE                 STATUS          READY
# es-argocd-platform-prod01     eso-store-platform    SecretSynced    True
# es-cluster-platform-test01    eso-store-platform    SecretSynced    True
# es-cluster-shared-prod01      eso-store-platform    SecretSynced    True
# es-cluster-shared-test01      eso-store-platform    SecretSynced    True

# Check that cluster secrets were created
kubectl get secret -n platform-argocd | grep cluster-

# Expected output:
# cluster-platform-prod01
# cluster-platform-test01
# cluster-shared-prod01
# cluster-shared-test01

# Verify cluster label
kubectl get secret cluster-platform-prod01 -n platform-argocd \
  -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/secret-type}'
# Expected: cluster
```

**Additional Documentation:**

For advanced scenarios and detailed explanations, see:
- [Cluster Secrets README](../templates/argocd/secrets/CLUSTER_SECRETS_README.md) - Manual process details
- [ArgoCD Cluster Registration Proposal](../ARGOCD_CLUSTER_REGISTRATION_PROPOSAL.md) - Complete guide with examples

### 11. Access ArgoCD UI

Once Netscaler Ingress Controller is deployed, access ArgoCD:

```bash
# Get initial admin password
kubectl get secret argocd-initial-admin-secret -n platform-argocd \
  -o jsonpath='{.data.password}' | base64 -d

# Access UI (based on your ingress configuration)
# URL: https://<argocd-domain-from-values>
```

**Note:** With OIDC configured, you can also login using your organization's identity provider.

## Deploy Applications

### Option A: App of Apps Pattern (Recommended)

Deploy the app-of-apps to have ArgoCD manage all platform applications:

```bash
kubectl apply -f deployments/platform-prod01/app-of-apps/platform-prod01.yaml
```

### Option B: Individual Applications

Deploy applications individually as needed:

```bash
kubectl apply -f deployments/platform-prod01/argocd-apps/
```

## Verification

After deployment, verify ArgoCD is working:

```bash
# Check all pods are running
kubectl get pods -n platform-argocd

# Check ArgoCD server
kubectl get svc argocd-server -n platform-argocd

# Check ingress
kubectl get ingress -n platform-argocd

# List registered clusters (requires argocd CLI or UI)
# argocd cluster list
```

## Troubleshooting

### OIDC Login Fails

```bash
# Check OIDC secret exists and has correct keys
kubectl get secret argocd-oidc -n platform-argocd
kubectl describe secret argocd-oidc -n platform-argocd

# Check ArgoCD server logs
kubectl logs -n platform-argocd -l app.kubernetes.io/name=argocd-server --tail=100
```

### Cluster Not Appearing in ArgoCD

```bash
# Check cluster secret exists
kubectl get secret cluster-<name> -n platform-argocd

# Verify secret has correct label
kubectl get secret cluster-<name> -n platform-argocd \
  -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/secret-type}'

# Check ExternalSecret status
kubectl describe externalsecret es-cluster-<name> -n platform-argocd

# Restart ArgoCD application controller
kubectl rollout restart statefulset argocd-application-controller -n platform-argocd
```

### Repository Connection Issues

```bash
# Check repository secret
kubectl get secret platform-repo -n platform-argocd

# Check ArgoCD repo server logs
kubectl logs -n platform-argocd -l app.kubernetes.io/name=argocd-repo-server --tail=100
```

## Next Steps

1. **Configure RBAC** - Set up role-based access control for users/teams
2. **Deploy Platform Services** - Use ArgoCD to deploy cert-manager, ingress, etc.
3. **Monitor** - Access ArgoCD UI to monitor application health and sync status

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [External Secrets JSON Guide](../EXTERNAL_SECRETS_JSON_GUIDE.md)
- [ArgoCD Cluster Registration Proposal](../ARGOCD_CLUSTER_REGISTRATION_PROPOSAL.md)
- [Cluster Secrets README](../templates/argocd/secrets/CLUSTER_SECRETS_README.md)
