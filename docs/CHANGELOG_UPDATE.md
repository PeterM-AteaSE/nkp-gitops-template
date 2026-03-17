# Repository Update Summary

---

## ArgoCD Cluster Registration & Comprehensive Documentation

**Date:** 17-18 February 2026  
**Author:** GitHub Copilot

### Overview

Comprehensive implementation of ArgoCD cluster registration using External Secrets Operator with token-based authentication. Created automation tooling, templates, and three comprehensive guides to support multi-cluster management.

### New Features

#### 1. ArgoCD Cluster Registration Templates

Created ExternalSecret manifests for automated cluster credential management:

- **es-argocd-cluster.yaml** - Generic template for cluster registration
- **es-cluster-platform-prod01.yaml** - Platform production cluster (<CLUSTER_PROD_API_SERVER_IP>:443)
- **es-cluster-platform-test01.yaml** - Platform test cluster (<CLUSTER_TEST_API_SERVER_IP>:443)
- **es-cluster-shared-prod01.yaml** - Shared production cluster (<CLUSTER_SHARED_PROD_API_SERVER_IP>:443)
- **es-cluster-shared-test01.yaml** - Shared test cluster (<CLUSTER_SHARED_TEST_API_SERVER_IP>:443)

**Authentication Method:** Token-based (bearerToken + CA certificate)  
**Secret Source:** Azure Key Vault (`<AZURE_KEY_VAULT_NAME>`)

#### 2. Automation Script

**File:** `templates/argocd/secrets/create-cluster-secret.sh`

Features:
- Extracts credentials from kubeconfig (bearer token or client certificate)
- Stores credentials securely in Azure Key Vault
- Generates ExternalSecret manifest from template
- Optional automatic deployment to cluster
- Support for both token-based and certificate-based authentication
- Comprehensive error handling and validation

Usage:
```bash
./create-cluster-secret.sh <cluster-name> <context-name> <user-name> <auth-method>
```

Example:
```bash
./create-cluster-secret.sh platform-test01 platform-test01-admin default token
```

#### 3. Comprehensive Documentation

Created three new comprehensive guides:

**A. EXTERNAL_SECRETS_JSON_GUIDE.md** (1,200+ lines)
- Deep dive into creating JSON-valued secrets with External Secrets Operator
- 5 different approaches with complete examples:
  1. Template-based approach (ExternalSecret with stringTemplate)
  2. Complete JSON in vault (single Azure Key Vault secret)
  3. Hybrid static/dynamic approach
  4. Complex nested structures
  5. Multi-file configurations
- Decision matrix for choosing approaches
- Azure Key Vault integration examples
- Troubleshooting guide
- Best practices for GitOps workflows

**B. ARGOCD_CLUSTER_REGISTRATION_PROPOSAL.md** (600+ lines)
- Customer-facing proposal for cluster registration automation
- Architecture overview with diagrams
- Complete implementation guide
- Security considerations
- Token-based vs certificate-based authentication comparison
- Quick start examples
- Demo plan and timeline

**C. templates/argocd/secrets/CLUSTER_SECRETS_README.md** (400+ lines)
- Step-by-step technical documentation
- Manual cluster registration walkthrough
- Automation script usage guide
- Token extraction procedures
- Azure Key Vault setup instructions
- Troubleshooting procedures
- Verification steps

### Documentation Updates

#### 1. README.md
- ✅ Added "Documentation" section with links to 3 comprehensive guides
- ✅ Added "Automation Scripts" section documenting create-cluster-secret.sh
- ✅ Organized documentation by purpose (guides vs. bootstrap instructions)

#### 2. bootstrap/ESO.md (Complete Rewrite)
- ✅ Complete rewrite from 15 lines to 150+ lines
- ✅ Added detailed bootstrap process (6 numbered steps)
- ✅ Added prerequisites section
- ✅ Added wait commands for SecretStore readiness
- ✅ Added verification steps
- ✅ Added troubleshooting section
- ✅ Added references to new comprehensive guides
- ✅ Added next steps pointing to ArgoCD bootstrap

#### 3. bootstrap/ArgoCD.md (Complete Rewrite)
- ✅ Removed all TODO comments
- ✅ Expanded from placeholder to comprehensive 10-step guide
- ✅ Added prerequisites section (kubectl, Azure CLI, ESO requirements)
- ✅ Added detailed cluster registration section (automated + manual options)
- ✅ Added references to cluster secrets documentation
- ✅ Added troubleshooting section (OIDC, cluster, repository issues)
- ✅ Added verification commands
- ✅ Added links to comprehensive guides
- ✅ Documented OIDC secret creation via ExternalSecret
- ✅ Documented platform repository secret setup

#### 4. templates/argocd/README.md (Complete Rewrite)
- ✅ Complete restructure to match actual directory layout
- ✅ Removed references to non-existent env/ directory
- ✅ Documented actual structure: secrets/, eso/, values/, configmaps/, projects/
- ✅ Added comprehensive cluster registration section
- ✅ Documented automation script usage
- ✅ Added table of registered clusters with server URLs
- ✅ Updated OIDC configuration documentation
- ✅ Added secrets management section
- ✅ Expanded troubleshooting with ESO-specific issues
- ✅ Added monitoring section
- ✅ Added links to all comprehensive guides
- ✅ Documented ytt templating usage
- ✅ Added customization instructions

#### 5. CHANGELOG_UPDATE.md
- ✅ Added this comprehensive changelog entry

### Technical Details

#### ArgoCD Helm Chart Configuration

**Chart Version:** v9.3.7  
**App Version:** v2.13.3

**Key Configuration:**
- **OIDC:** <CUSTOMER_FULLNAME> IdP with environment variable injection
- **RBAC:** Full permissions for `role:authenticated`
- **Ingress:** Citrix VPX (vpxingress) with SSL/TLS for web UI and gRPC
- **Secret Injection:** `extraEnvFrom` referencing `argocd-oidc` secret
- **Templating:** Carvel ytt for cluster-specific values

#### Azure Key Vault Secrets

**Key Vault:** `<AZURE_KEY_VAULT_NAME>`

**Required Secrets:**

1. **OIDC Authentication:**
   - `argocd-oidc-client-id`
   - `argocd-oidc-client-secret`

2. **Git Repository:**
   - `argocd-platform-repo-ssh-key`

3. **Cluster Credentials (per cluster):**
   - `argocd-cluster-{name}-token`
   - `argocd-cluster-{name}-ca`

#### Cluster Configurations

| Cluster Name | Server URL | Auth Method | Template File |
|-------------|-----------|------------|---------------|
| platform-prod01 | https://<CLUSTER_PROD_API_SERVER_IP>:443 | Token | es-cluster-platform-prod01.yaml |
| platform-test01 | https://<CLUSTER_TEST_API_SERVER_IP>:443 | Token | es-cluster-platform-test01.yaml |
| shared-prod01 | https://<CLUSTER_SHARED_PROD_API_SERVER_IP>:443 | Token | es-cluster-shared-prod01.yaml |
| shared-test01 | https://<CLUSTER_SHARED_TEST_API_SERVER_IP>:443 | Token | es-cluster-shared-test01.yaml |

### Build Script Fixes

**File:** `templates/argocd/build.sh`

Fixed issue in `helm_template()` function:
- **Problem:** Syntax error "unexpected end of file from '{' command"
- **Root Cause:** Missing output redirection causing incomplete function
- **Solution:** Added `> "$DEPLOYMENT_DIR/install/install.yaml"` to complete output redirection

### Files Modified

**New Files Created:**
- ✅ `/EXTERNAL_SECRETS_JSON_GUIDE.md`
- ✅ `/ARGOCD_CLUSTER_REGISTRATION_PROPOSAL.md`
- ✅ `/templates/argocd/secrets/CLUSTER_SECRETS_README.md`
- ✅ `/templates/argocd/secrets/create-cluster-secret.sh` (executable)
- ✅ `/templates/argocd/secrets/es-cluster-platform-prod01.yaml`
- ✅ `/templates/argocd/secrets/es-cluster-platform-test01.yaml`
- ✅ `/templates/argocd/secrets/es-cluster-shared-prod01.yaml`
- ✅ `/templates/argocd/secrets/es-cluster-shared-test01.yaml`

**Files Modified:**
- ✅ `/README.md` - Added documentation and automation sections
- ✅ `/bootstrap/ESO.md` - Complete rewrite with comprehensive instructions
- ✅ `/bootstrap/ArgoCD.md` - Complete rewrite with 10-step deployment guide
- ✅ `/templates/argocd/README.md` - Complete restructure and expansion
- ✅ `/templates/argocd/build.sh` - Fixed helm_template() syntax error
- ✅ `/templates/argocd/secrets/es-argocd-cluster.yaml` - Updated for token-based auth
- ✅ `/templates/argocd/values/values.yaml` - Merged with new chart v9.3.7 values
- ✅ `/CHANGELOG_UPDATE.md` - Added this entry

### Testing & Verification

**Build Script:**
```bash
cd templates/argocd
./build.sh platform-prod01
# ✅ Completes successfully without errors
```

**Generated Manifests:**
- ✅ `deployments/platform-prod01/argocd/install/install.yaml`
- ✅ `deployments/platform-prod01/argocd/eso/eso-store-platform.yaml`
- ✅ `deployments/platform-prod01/argocd/secrets/es-argocd-oidc.yaml`
- ✅ `deployments/platform-prod01/argocd/secrets/es-cluster-*.yaml` (4 files)
- ✅ `deployments/platform-prod01/argocd/projects/es-platform-repo.yaml`

### Benefits

1. **Automation:** Reduced cluster registration from 30+ manual steps to single command
2. **Security:** Credentials never stored in Git, always pulled from Azure Key Vault
3. **Consistency:** Templated approach ensures uniform configuration across clusters
4. **Documentation:** Comprehensive guides for both operators and decision-makers
5. **Flexibility:** Support for both token-based and certificate-based authentication
6. **Troubleshooting:** Detailed debugging procedures for common issues

### Next Steps

1. ⏭️ Test automation script on test cluster
2. ⏭️ Deploy cluster registration to platform-prod01
3. ⏭️ Verify clusters appear in ArgoCD UI
4. ⏭️ Roll out to remaining clusters (shared-prod01, shared-test01)
5. ⏭️ Document certificate-based authentication if needed
6. ⏭️ Create ArgoCD Application manifests for platform services
7. ⏭️ Implement app-of-apps pattern

### References

- [External Secrets JSON Guide](EXTERNAL_SECRETS_JSON_GUIDE.md)
- [ArgoCD Cluster Registration Proposal](ARGOCD_CLUSTER_REGISTRATION_PROPOSAL.md)
- [Cluster Secrets README](templates/argocd/secrets/CLUSTER_SECRETS_README.md)
- [ArgoCD Bootstrap Guide](bootstrap/ArgoCD.md)
- [ESO Bootstrap Guide](bootstrap/ESO.md)

---

## External Secrets Operator Integration

**Date:** 19 January 2026  
**Last Commit:** c31d624 - feat(multiple): Pushing efforts from work-session

## New Application Detected

### External Secrets Operator
- **Location:** `templates/external-secrets-operator/`
- **Namespace:** `platform-eso`
- **Helm Chart:** `external-secrets/external-secrets` v1.2.1
- **Purpose:** Synchronize secrets from external secret management systems (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, Google Secret Manager, etc.)
- **Dependencies:** cert-manager (optional, for webhook TLS)
- **Deployment Layer:** Layer 2 (Platform Extensions)

**New Cluster Support:**
- gpu-prod01
- gpu-test01
- delad-test01
- delad-prod01
- platform-test01
- platform-prod01
- local-test

## Documentation Updates Made

### 1. README.md
- ✅ Added `external-secrets-operator` to Available Applications list
- ✅ Added Helm repository for External Secrets: `external-secrets https://charts.external-secrets.io`
- ✅ Updated application count from 6 to 9 total applications

### 2. CLUSTER_WORKFLOW.md
- ✅ Added External Secrets Operator to Platform Applications section
- ✅ Renumbered applications to include ESO in Core Infrastructure
- ✅ Updated total application count to 9

### 3. DEPLOYMENT_GUIDE.md
- ✅ Added Layer 2 deployment section for External Secrets Operator
- ✅ Included manual deployment steps with:
  - Build commands
  - Deploy commands
  - Wait/verification commands
  - Expected output
  - CRD verification
- ✅ Updated automated deployment description to include ESO
- ✅ Updated post-deployment verification commands
- ✅ Updated deployment summary to include ESO pod count
- ✅ Updated rollback procedures
- ✅ Updated architecture diagram (Mermaid) to show ESO
- ✅ Updated rebuild manifests loop to include ESO

### 4. deploy-cluster.sh
- ✅ Updated `deploy_layer2_platform_extensions()` function to deploy ESO
- ✅ Added ESO CRD wait commands:
  - `externalsecrets.external-secrets.io`
  - `secretstores.external-secrets.io`
  - `clustersecretstores.external-secrets.io`
- ✅ Updated deployment summary to list ESO in Layer 2
- ✅ Updated verification command to include 'eso' grep pattern
- ✅ Added externalsecrets check to verification commands
- ✅ Updated usage help text with Layer 2 applications

## Complete Application List (9 Total)

### Layer 0: Foundation
1. **olmv0** - Operator Lifecycle Manager v0

### Layer 1: GitOps & Security  
2. **cert-manager** - Certificate management (platform-cert-manager)
3. **argocd** - GitOps continuous delivery (platform-argocd)

### Layer 2: Platform Extensions
4. **adcs-issuer** - MS AD Certificate Services (platform-adcs-issuer)
5. **external-secrets-operator** - External secrets sync (platform-eso) **[NEW]**

### Layer 3: Networking
6. **netscaler-ingress** - Citrix ingress controller (platform-netscaler-ingress)
7. **externaldns-internal** - DNS automation (platform-externaldns-internal)

### Layer 4: Applications
8. **ollama** - Local LLM inference (ollama)
9. **open-webui** - LLM web interface (open-webui)

## Helm Repositories

All required Helm repositories are in `setup/helm-repo.sh`:

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo add external-secrets https://charts.external-secrets.io     # [NEW]
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add harbor https://helm.goharbor.io
helm repo add netscaler https://netscaler.github.io/netscaler-helm-charts/
helm repo add prometheus-msteams https://prometheus-msteams.github.io/prometheus-msteams/
helm repo add djkormo-adcs-issuer https://djkormo.github.io/adcs-issuer/
helm repo add open-webui https://helm.openwebui.com/
helm repo add otwld https://helm.otwld.com/
```

## Deployment Order (Updated)

```
Layer 0: OLMv0
    ↓
Layer 1: cert-manager + ArgoCD (parallel possible)
    ↓
Layer 2: adcs-issuer + external-secrets-operator (parallel possible)
    ↓
Layer 3: netscaler-ingress + externaldns-internal (parallel possible)
    ↓
Layer 4: ollama → open-webui (sequential, open-webui depends on ollama)
```

## Verification Commands (Updated)

```bash
# Check all platform pods
kubectl get pods -A | grep -E 'cert-manager|argocd|adcs|eso|netscaler|external-dns|ollama|open-webui'

# Check External Secrets resources
kubectl get externalsecrets -A
kubectl get secretstores -A
kubectl get clustersecretstores -A

# Deployment summary
echo "External Secrets: $(kubectl get pods -n platform-eso --no-headers 2>/dev/null | wc -l) pods"
```

## Files Modified

- ✅ `/README.md` - Added ESO to available applications
- ✅ `/CLUSTER_WORKFLOW.md` - Updated platform applications list
- ✅ `/DEPLOYMENT_GUIDE.md` - Added complete ESO deployment section
- ✅ `/deploy-cluster.sh` - Added ESO to Layer 2 deployment

## Files Unchanged (Already Correct)

- `setup/helm-repo.sh` - Already contains external-secrets repository
- `templates/external-secrets-operator/build.sh` - New file, no changes needed
- `templates/external-secrets-operator/values/new-values.yaml` - New file, no changes needed

## ArgoCD Deployment Notes

📝 **ArgoCD Uses Operator Pattern (Not Helm)**  
- File: `templates/argocd/build.sh` contains placeholder Helm config
- Actual deployment: Via ArgoCD Operator using CR in `templates/argocd/operator/argocd-deploy.yaml`
- Status: **Work-in-progress** - deployment not yet complete
- The build.sh script is not currently used for ArgoCD deployment
- ArgoCD is installed via OLM operator, not via the standard build/deploy pattern

## Testing Recommendations

1. **Test External Secrets Operator deployment:**
   ```bash
   cd templates/external-secrets-operator
   ./build.sh platform-test01
   kubectl apply -f ../../deployments/platform-test01/external-secrets-operator/ --recursive
   ```

2. **Verify CRDs are created:**
   ```bash
   kubectl get crd | grep external-secrets.io
   ```

3. **Test full automated deployment:**
   ```bash
   DRY_RUN=true ./deploy-cluster.sh platform-test01
   ```

4. **Fix ArgoCD build script and test:**
   ```bash
   # After fixing HELM_REPOSITORY in templates/argocd/build.sh
   cd templates/argocd
   ./build.sh platform-test01
   ```

## Next Steps

1. ✅ Documentation fully updated
2. ⏭️ Test ESO deployment on test cluster
3. ⏭️ Fix ArgoCD build.sh HELM_REPOSITORY
4. ⏭️ Test complete platform deployment with deploy-cluster.sh
5. ⏭️ Commit documentation changes to repository
