# ArgoCD Helm Deployment

This directory contains the Helm-based deployment configuration for ArgoCD with External Secrets Operator (ESO) integration.

## Overview

This deployment uses the official ArgoCD Helm chart (v9.3.7) with the following features:
- **External Secrets Operator integration** for secure secret management via Azure Key Vault
- **OIDC authentication** with <CUSTOMER_FULLNAME> identity provider
- **Automated cluster registration** using ExternalSecrets
- **ytt templating** for environment-specific configuration
- **Citrix VPX ingress** with SSL termination

## Directory Structure

```
argocd/
├── build.sh                              # Build script to generate deployment manifests
├── values/
│   └── values.yaml                      # Helm values with ytt templates
├── projects/
│   ├── appproject-platform.yaml        # Platform AppProject definition
│   └── es-platform-repo.yaml           # Git repository ExternalSecret
├── secrets/
│   ├── CLUSTER_SECRETS_README.md       # Detailed cluster registration guide
│   ├── create-cluster-secret.sh        # Automation script for cluster registration
│   ├── es-argocd-oidc.yaml             # OIDC authentication secret
│   ├── es-cluster-platform-prod01.yaml # Platform production cluster
│   ├── es-cluster-platform-test01.yaml # Platform test cluster
│   ├── es-cluster-shared-prod01.yaml   # Shared production cluster
│   └── es-cluster-shared-test01.yaml   # Shared test cluster
├── eso/
│   └── eso-store-platform.yaml         # SecretStore for Azure Key Vault
├── projects/
│   └── es-platform-repo.yaml           # ExternalSecret for Git repository SSH key
└── configmaps/
    └── (future ConfigMap resources)
```

## Features

- **Helm-based deployment**: Uses official ArgoCD Helm chart v9.3.7
- **extraEnvFrom support**: Inject OIDC credentials from secrets into ArgoCD components:
  - Server (for OIDC authentication)
- **OIDC integration**: <CUSTOMER_FULLNAME> IdP with environment variable injection
- **RBAC**: Pre-configured policies with `role:authenticated` for logged-in users
- **Ingress**: Citrix VPX with SSL/TLS for both web UI and gRPC
- **Cluster Management**: Automated multi-cluster registration via ExternalSecrets
- **ytt Templating**: Environment-specific values using Carvel ytt

## Bootstrap Secrets

ArgoCD requires three types of secrets to function:

### 1. AppProject (Static Configuration)
**File:** `projects/appproject-platform.yaml`  
**Purpose:** Defines RBAC roles and allowed resources for the platform project  
**Deployment:** Apply directly with `kubectl apply`  
**Contains:**
- Source repository allow list
- Destination cluster/namespace rules
- RBAC roles (admin, operator, viewer)

### 2. Repository Secret (From Azure Key Vault)
**File:** `projects/es-platform-repo.yaml`  
**Purpose:** Git repository access credentials  
**Type:** ExternalSecret (synced from Azure Key Vault)  
**Required in Key Vault:**
- `argocd-sshKey-nkp-gitops` - SSH private key for GitHub access

**Creates Kubernetes Secret:**
```yaml
data:
  insecure: "false"
  name: "<GITHUB_REPO>"
  project: "platform"
  type: "git"
  url: "git@github.com:<GITHUB_ORG>/<GITHUB_REPO>.git"
  sshPrivateKey: <from-azure-kv>
```

### 3. Cluster Secrets (From Azure Key Vault)
**Files:** `secrets/es-cluster-*.yaml`  
**Purpose:** Credentials for managed Kubernetes clusters  
**Type:** ExternalSecret (synced from Azure Key Vault)  
**Required in Key Vault (per cluster):**
- `argocd-cluster-<name>-server` - Kubernetes API server URL
- `argocd-cluster-<name>-token` OR cert/key - Authentication credentials
- `argocd-cluster-<name>-ca` - CA certificate

See [secrets/CLUSTER_SECRETS_README.md](secrets/CLUSTER_SECRETS_README.md) for detailed instructions.

## Quick Start

### Prerequisites

1. **kubectl** with access to target cluster
2. **helm** CLI installed
3. **ytt** (Carvel) installed for templating
4. **Azure CLI** authenticated (`az login`)
5. **External Secrets Operator** deployed on target cluster
6. **Azure Key Vault**: `<AZURE_KEY_VAULT_NAME>` with appropriate access

### Deployment Steps

```bash
# 1. Navigate to this directory
cd templates/argocd

# 2. Build manifests for your cluster
./build.sh platform-prod01

# 3. Apply generated manifests
kubectl apply -f ../../deployments/platform-prod01/argocd/eso/eso-store-platform.yaml
kubectl apply -f ../../deployments/platform-prod01/argocd/secrets/es-argocd-oidc.yaml

# 4. Wait for OIDC secret to be created by ESO
kubectl wait --for=condition=ready externalsecret/es-argocd-oidc \
  -n platform-argocd --timeout=60s

# 5. Deploy ArgoCD
kubectl apply --server-side --force-conflicts -f ../../deployments/platform-prod01/argocd/install/install.yaml

# 6. Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n platform-argocd --timeout=300s

# 7. Deploy AppProject for platform infrastructure
kubectl apply -f ../../deployments/platform-prod01/argocd/projects/appproject-platform.yaml

# 8. Deploy platform repository ExternalSecret
kubectl apply -f ../../deployments/platform-prod01/argocd/projects/es-platform-repo.yaml

# 9. Wait for repository secret to sync
kubectl wait --for=condition=ready externalsecret/es-platform-repo \
  -n platform-argocd --timeout=60s

# 10. Register managed clusters (see Cluster Registration section)
```

Full step-by-step instructions: [bootstrap/ArgoCD.md](../../bootstrap/ArgoCD.md)

## Configuration

### Helm Values (values/values.yaml)

The `values.yaml` file uses ytt templating for environment-specific configuration:

#### ytt Variables

```yaml
#@data/values
---
argocd:
  server:
    serverUrl: argocd.example.com
    grpcUrl: argocd-grpc.example.com
```

These are replaced during build by cluster-specific values from `../../clusters/{cluster}.yaml`.

#### Key Configuration Sections

**1. Global Domain**
```yaml
global:
  domain: #@ data.values.argocd.server.serverUrl
```

**2. OIDC Configuration**
```yaml
configs:
  params:
    server.insecure: false
  cm:
    url: #@ "https://" + data.values.argocd.server.serverUrl
    oidc.config: |
      name: <CUSTOMER_FULLNAME> IdP
      issuer: https://idp.<CUSTOMER_DOMAIN>
      requestedScopes: ["openid", "profile", "email", "groups"]
      clientID: $OIDC_CLIENT_ID
      clientSecret: $OIDC_CLIENT_SECRET
```

**3. RBAC Policy**
```yaml
configs:
  rbac:
    policy.csv: |
      p, role:authenticated, applications, *, */*, allow
      p, role:authenticated, clusters, *, *, allow
      p, role:authenticated, repositories, *, *, allow
      # ... full permissions for authenticated users
    scopes: '[groups, email]'
```

**4. Environment Variable Injection**
```yaml
server:
  extraEnvFrom:
    - secretRef:
        name: argocd-oidc
        optional: false
```

**5. Ingress Configuration**
```yaml
server:
  ingress:
    enabled: true
    ingressClassName: vpxingress
    hostname: #@ data.values.argocd.server.serverUrl
    annotations:
      ingress.citrix.com/insecure-termination: "allow"
      ingress.citrix.com/secure-backend: "True"
    tls: true

  ingressGrpc:
    enabled: true
    ingressClassName: vpxingress
    hostname: #@ data.values.argocd.server.grpcUrl
    annotations:
      ingress.citrix.com/insecure-termination: "allow"
      ingress.citrix.com/secure-backend: "True"
    tls: true
```

### Build Script (build.sh)

The `build.sh` script generates deployment manifests:

```bash
./build.sh <cluster-name>
```

**Supported clusters:**
- `platform-prod01`
- `platform-test01`

**What it does:**
1. Loads cluster-specific values from `../../clusters/{cluster}.yaml`
2. Merges with `values/values.yaml` using ytt
3. Generates Helm template
4. Outputs to `../../deployments/{cluster}/argocd/install/install.yaml`
5. Copies ExternalSecret manifests to deployment directory

## Cluster Registration

ArgoCD needs credentials to manage other Kubernetes clusters. This is handled through ExternalSecrets that pull credentials from Azure Key Vault.

### Register Clusters Automatically (Recommended)

Use the automation script:

```bash
cd secrets/

# Register platform-test01 cluster
./create-cluster-secret.sh platform-test01 platform-test01-admin default token

# Register shared-prod01 cluster
./create-cluster-secret.sh shared-prod01 shared-prod01-admin default token

# Register shared-test01 cluster
./create-cluster-secret.sh shared-test01 shared-test01-admin default token
```

**The script will:**
1. Extract credentials from your kubeconfig
2. Store bearer token and CA certificate in Azure Key Vault
3. Create an ExternalSecret manifest
4. Optionally apply the manifest to the cluster

**Arguments:**
- `$1`: Cluster name (e.g., `platform-test01`)
- `$2`: Kubeconfig context name
- `$3`: Kubeconfig user name (usually `default`)
- `$4`: Auth method (`token` or `cert`)

### Manual Cluster Registration

For step-by-step instructions on manual registration:
- [secrets/CLUSTER_SECRETS_README.md](secrets/CLUSTER_SECRETS_README.md)

### Verify Cluster Registration

```bash
# Check that ExternalSecrets are ready
kubectl get externalsecret -n platform-argocd | grep cluster-

# Check that cluster secrets were created
kubectl get secret -n platform-argocd | grep cluster-

# Verify cluster secret has correct label
kubectl get secret cluster-platform-test01 -n platform-argocd \
  -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/secret-type}'
# Expected output: cluster
```

### Registered Clusters

Current cluster configurations:

| Cluster Name | Server URL | Auth Method | ExternalSecret |
|-------------|-----------|------------|----------------|
| platform-prod01 | https://<CLUSTER_PROD_API_SERVER_IP>:443 | Token | es-cluster-platform-prod01.yaml |
| platform-test01 | https://<CLUSTER_TEST_API_SERVER_IP>:443 | Token | es-cluster-platform-test01.yaml |
| shared-prod01 | https://<CLUSTER_SHARED_PROD_API_SERVER_IP>:443 | Token | es-cluster-shared-prod01.yaml |
| shared-test01 | https://<CLUSTER_SHARED_TEST_API_SERVER_IP>:443 | Token | es-cluster-shared-test01.yaml |

## Secrets Management

All secrets are managed via External Secrets Operator (ESO) pulling from Azure Key Vault.

### Azure Key Vault Secrets

**Required secrets in `<AZURE_KEY_VAULT_NAME>`:**

1. **OIDC Authentication**
   - `argocd-oidc-client-id`: OIDC client ID
   - `argocd-oidc-client-secret`: OIDC client secret

2. **Git Repository Access**
   - `argocd-platform-repo-ssh-key`: SSH private key for Git repository

3. **Cluster Credentials** (for each managed cluster)
   - `argocd-cluster-{name}-token`: Bearer token for authentication
   - `argocd-cluster-{name}-ca`: Base64-encoded CA certificate

### ExternalSecret Resources

**OIDC Secret** (`secrets/es-argocd-oidc.yaml`):
Creates Kubernetes secret `argocd-oidc` with OIDC credentials.

**Platform Repository** (`projects/es-platform-repo.yaml`):
Creates Kubernetes secret `platform-repo` with Git SSH key.

**Cluster Secrets** (`secrets/es-cluster-*.yaml`):
Creates Kubernetes secrets for ArgoCD cluster registration.

### SecretStore

The `eso-store-platform.yaml` defines the connection to Azure Key Vault:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: eso-store-platform
  namespace: platform-argocd
spec:
  provider:
    azurekv:
      authType: WorkloadIdentity
      vaultUrl: https://<AZURE_KEY_VAULT_NAME>.vault.azure.net
      serviceAccountRef:
        name: eso-store-aks
```

## Environment Variables

The following environment variables are injected into ArgoCD server via `extraEnvFrom`:

### From Secret (`argocd-oidc`)
- `OIDC_CLIENT_ID`: OIDC client ID for <CUSTOMER_FULLNAME> IdP
- `OIDC_CLIENT_SECRET`: OIDC client secret for <CUSTOMER_FULLNAME> IdP

These variables are referenced in the OIDC configuration:
```yaml
oidc.config: |
  clientID: $OIDC_CLIENT_ID
  clientSecret: $OIDC_CLIENT_SECRET
```

## Customization

### Modifying Helm Values

1. Edit `values/values.yaml`
2. Use ytt template syntax for dynamic values:
   ```yaml
   #@ data.values.argocd.server.serverUrl
   ```
3. Rebuild manifests: `./build.sh <cluster>`

### Adding Cluster-Specific Values

1. Edit cluster definition in `../../clusters/{cluster}.yaml`
2. Add argocd section:
   ```yaml
   argocd:
     server:
       serverUrl: argocd.example.com
       grpcUrl: argocd-grpc.example.com
   ```
3. Rebuild manifests

### Changing Helm Chart Version

Edit `build.sh`:
```bash
HELM_CHART_VERSION="9.3.7"  # Update to desired version
```

Then rebuild manifests for all clusters.

## Troubleshooting

### OIDC Login Fails

```bash
# Verify OIDC secret exists
kubectl get secret argocd-oidc -n platform-argocd

# Check secret has correct keys
kubectl get secret argocd-oidc -n platform-argocd -o jsonpath='{.data}' | jq 'keys'
# Expected: ["OIDC_CLIENT_ID", "OIDC_CLIENT_SECRET"]

# Check ExternalSecret status
kubectl describe externalsecret es-argocd-oidc -n platform-argocd

# Check ArgoCD server logs
kubectl logs -n platform-argocd -l app.kubernetes.io/name=argocd-server --tail=100
```

### Cluster Not Appearing in ArgoCD

```bash
# Check ExternalSecret status
kubectl get externalsecret -n platform-argocd | grep cluster-
kubectl describe externalsecret es-cluster-platform-test01 -n platform-argocd

# Verify secret was created
kubectl get secret cluster-platform-test01 -n platform-argocd

# Check secret has correct label
kubectl get secret cluster-platform-test01 -n platform-argocd \
  -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/secret-type}'
# Expected: cluster

# Inspect secret structure
kubectl get secret cluster-platform-test01 -n platform-argocd -o yaml

# Restart ArgoCD application controller
kubectl rollout restart statefulset argocd-application-controller -n platform-argocd
```

### ExternalSecret Not Syncing

```bash
# Check SecretStore is ready
kubectl get secretstore eso-store-platform -n platform-argocd
kubectl describe secretstore eso-store-platform -n platform-argocd

# Check ESO pod logs
kubectl logs -n external-secrets-operator -l app.kubernetes.io/name=external-secrets

# Verify Azure Key Vault access
kubectl exec -n external-secrets-operator deploy/external-secrets -- \
  env | grep AZURE

# Manually trigger sync
kubectl annotate externalsecret es-argocd-oidc -n platform-argocd \
  force-sync=$(date +%s) --overwrite
```

### Check Environment Variables in Pods

```bash
# Check ArgoCD server has OIDC vars
kubectl exec -n platform-argocd deployment/argocd-server -- env | grep OIDC

# If not present, check extraEnvFrom
kubectl get deployment argocd-server -n platform-argocd -o yaml | grep -A10 envFrom
```

### Repository Connection Issues

```bash
# Check repository secret exists
kubectl get secret platform-repo -n platform-argocd

# Check ExternalSecret status
kubectl describe externalsecret es-platform-repo -n platform-argocd

# Check repo server logs
kubectl logs -n platform-argocd -l app.kubernetes.io/name=argocd-repo-server --tail=100
```

### Build Script Issues

```bash
# Verify ytt is installed
ytt version

# Verify helm is installed
helm version

# Check cluster values file exists
cat ../../clusters/platform-prod01.yaml

# Test ytt template rendering
ytt -f values/values.yaml -f ../../clusters/platform-prod01.yaml

# Run build with debug output
bash -x ./build.sh platform-prod01
```

## Monitoring

### Check ArgoCD Health

```bash
# Check all pods
kubectl get pods -n platform-argocd

# Check services
kubectl get svc -n platform-argocd

# Check ingress
kubectl get ingress -n platform-argocd

# Check all ArgoCD components
kubectl get all -n platform-argocd -l app.kubernetes.io/part-of=argocd
```

### Access ArgoCD UI

```bash
# Get initial admin password
kubectl get secret argocd-initial-admin-secret -n platform-argocd \
  -o jsonpath='{.data.password}' | base64 -d

# Port-forward for local access
kubectl port-forward -n platform-argocd svc/argocd-server 8080:443

# Access at: https://localhost:8080
# Or use configured ingress URL
```

## Additional Documentation

### Comprehensive Guides
- [External Secrets JSON Guide](../../EXTERNAL_SECRETS_JSON_GUIDE.md) - Deep dive into creating JSON-valued secrets with ESO
- [ArgoCD Cluster Registration Proposal](../../ARGOCD_CLUSTER_REGISTRATION_PROPOSAL.md) - Complete guide with architecture and examples
- [Cluster Secrets README](secrets/CLUSTER_SECRETS_README.md) - Step-by-step cluster registration instructions

### Bootstrap Instructions
- [Bootstrapping ArgoCD](../../bootstrap/ArgoCD.md) - Complete deployment guide
- [Bootstrapping ESO](../../bootstrap/ESO.md) - External Secrets Operator setup

### Official Documentation
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [External Secrets Operator](https://external-secrets.io/)
- [Carvel ytt](https://carvel.dev/ytt/)

## Migration Notes

### From Operator-Based Deployment

If migrating from the operator-based ArgoCD deployment:

1. **Export existing configuration:**
   ```bash
   kubectl get argocd argocd-central -n platform-argocd -o yaml > old-config.yaml
   ```

2. **Scale down operator-based ArgoCD:**
   ```bash
   kubectl delete argocd argocd-central -n platform-argocd
   ```

3. **Preserve secrets if needed:**
   ```bash
   # Backup secrets
   kubectl get secret -n platform-argocd -o yaml > secrets-backup.yaml
   ```

4. **Follow deployment steps** in this README

5. **Migrate applications and repositories** via ArgoCD UI or CLI

### Version Compatibility

- **ArgoCD Helm Chart**: v9.3.7
- **ArgoCD Application**: v2.13.3 (bundled with chart)
- **External Secrets Operator**: v0.12.1+
- **Kubernetes**: v1.27+

## Contributing

When making changes to ArgoCD configuration:

1. Update `values/values.yaml` with changes
2. Test by rebuilding: `./build.sh platform-test01`
3. Apply to test cluster first
4. Verify functionality
5. Roll out to production cluster
6. Update this README with any new features or changes

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review [Additional Documentation](#additional-documentation)
3. Check ArgoCD and ESO logs
4. Contact platform team
