# ArgoCD GitOps — Customer Template

This repository is a template for deploying the ArgoCD GitOps stack to a new customer environment. It contains the full structure from a reference implementation with all customer-specific values replaced by placeholders.

---

## Quick Start

### 1. Create a new customer repo

```bash
# Clone/copy this template
cp -r argocd-gitops-template <CUSTOMER_SHORT_NAME>-argocd-gitops
cd <CUSTOMER_SHORT_NAME>-argocd-gitops
git init && git add . && git commit -m "chore(init): initial commit from argocd-gitops-template"
```

### 2. Fill in the placeholders

Run the helper script below (fill in your values first):

```bash
CUSTOMER_SHORT_NAME="acme"                    # e.g. "acme" (used in repo names)
CUSTOMER_FULLNAME="Acme Corporation"          # Full display name for ArgoCD OIDC
GITHUB_ORG="your-github-org"
GITHUB_REPO="${CUSTOMER_SHORT_NAME}-argocd-gitops"

CUSTOMER_DOMAIN="acme.se"                     # Public/primary domain
CUSTOMER_K8S_DOMAIN="k8s.acme.se"            # Kubernetes DNS zone
CUSTOMER_AD_DOMAIN="ad.acme.se"              # Active Directory domain
CUSTOMER_KERBEROS_REALM="AD.ACME.SE"         # Kerberos realm (uppercase)
CUSTOMER_INTERNAL_DOMAIN="acme.local"        # Internal/on-prem domain
CUSTOMER_ADCS_HOSTNAME="adcs.acme.local"     # ADCS certificate authority host
CUSTOMER_AD_KDC="dc01.ad.acme.se"           # AD Domain Controller / KDC
CUSTOMER_LAB_DOMAIN="k8s.lab.acme.mgmt"     # Lab cluster domain (if applicable)

AZURE_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_KEY_VAULT_NAME="kv-acme"

NETSCALER_NSIP="10.x.x.x"                   # NetScaler management/nitro-api IP

CLUSTER_PROD_NSVIP="10.x.x.x"              # prod: internal LAN VIP
CLUSTER_PROD_INTERNET_VIP="x.x.x.x"        # prod: public internet VIP
CLUSTER_PROD_SNIP="10.x.x.x"              # prod: NetScaler SNIP
CLUSTER_PROD_API_SERVER_IP="10.x.x.x"     # prod: Kubernetes API server IP

CLUSTER_TEST_NSVIP="10.x.x.x"             # test: internal LAN VIP
CLUSTER_TEST_INTERNET_VIP="x.x.x.x"       # test: public internet VIP
CLUSTER_TEST_SNIP="10.x.x.x"             # test: NetScaler SNIP
CLUSTER_TEST_API_SERVER_IP="10.x.x.x"    # test: Kubernetes API server IP

# Apply all replacements
FILES=$(find . -type f \( -name "*.yaml" -o -name "*.md" -o -name "*.sh" \) | grep -v '.git')

sed -i "s|<GITHUB_ORG>/<GITHUB_REPO>|${GITHUB_ORG}/${GITHUB_REPO}|g" $FILES
sed -i "s|<GITHUB_REPO>|${GITHUB_REPO}|g" $FILES
sed -i "s|<GITHUB_ORG>|${GITHUB_ORG}|g" $FILES
sed -i "s|<CUSTOMER_FULLNAME>|${CUSTOMER_FULLNAME}|g" $FILES
sed -i "s|<AZURE_TENANT_ID>|${AZURE_TENANT_ID}|g" $FILES
sed -i "s|<AZURE_KEY_VAULT_NAME>|${AZURE_KEY_VAULT_NAME}|g" $FILES
sed -i "s|<CUSTOMER_ADCS_HOSTNAME>|${CUSTOMER_ADCS_HOSTNAME}|g" $FILES
sed -i "s|<CUSTOMER_KERBEROS_REALM>|${CUSTOMER_KERBEROS_REALM}|g" $FILES
sed -i "s|<CUSTOMER_AD_KDC>|${CUSTOMER_AD_KDC}|g" $FILES
sed -i "s|<CUSTOMER_AD_DOMAIN>|${CUSTOMER_AD_DOMAIN}|g" $FILES
sed -i "s|<CUSTOMER_K8S_DOMAIN>|${CUSTOMER_K8S_DOMAIN}|g" $FILES  
sed -i "s|<CUSTOMER_DOMAIN>|${CUSTOMER_DOMAIN}|g" $FILES
sed -i "s|<CUSTOMER_INTERNAL_DOMAIN>|${CUSTOMER_INTERNAL_DOMAIN}|g" $FILES
sed -i "s|<CUSTOMER_LAB_DOMAIN>|${CUSTOMER_LAB_DOMAIN}|g" $FILES
sed -i "s|<NETSCALER_NSIP>|${NETSCALER_NSIP}|g" $FILES
sed -i "s|<CLUSTER_PROD_NSVIP>|${CLUSTER_PROD_NSVIP}|g" $FILES
sed -i "s|<CLUSTER_PROD_INTERNET_VIP>|${CLUSTER_PROD_INTERNET_VIP}|g" $FILES
sed -i "s|<CLUSTER_PROD_SNIP>|${CLUSTER_PROD_SNIP}|g" $FILES
sed -i "s|<CLUSTER_PROD_API_SERVER_IP>|${CLUSTER_PROD_API_SERVER_IP}|g" $FILES
sed -i "s|<CLUSTER_TEST_NSVIP>|${CLUSTER_TEST_NSVIP}|g" $FILES
sed -i "s|<CLUSTER_TEST_INTERNET_VIP>|${CLUSTER_TEST_INTERNET_VIP}|g" $FILES
sed -i "s|<CLUSTER_TEST_SNIP>|${CLUSTER_TEST_SNIP}|g" $FILES
sed -i "s|<CLUSTER_TEST_API_SERVER_IP>|${CLUSTER_TEST_API_SERVER_IP}|g" $FILES

echo "Done. Review git diff before committing."
```

---

## Placeholder Reference

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `<GITHUB_ORG>` | GitHub organization name | `<CUSTOMER_SHORT>-stad` |
| `<GITHUB_REPO>` | GitHub repository name | `acme-argocd-gitops` |
| `<CUSTOMER_FULLNAME>` | Display name used in ArgoCD OIDC | `Acme Corporation` |
| `<AZURE_TENANT_ID>` | Azure AD Tenant UUID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `<AZURE_KEY_VAULT_NAME>` | Azure Key Vault name | `kv-acme` |
| `<CUSTOMER_DOMAIN>` | Primary public domain | `acme.se` |
| `<CUSTOMER_K8S_DOMAIN>` | Kubernetes DNS zone | `k8s.acme.se` |
| `<CUSTOMER_AD_DOMAIN>` | Active Directory domain (FQDN) | `ad.acme.se` |
| `<CUSTOMER_KERBEROS_REALM>` | Kerberos realm (uppercase) | `AD.ACME.SE` |
| `<CUSTOMER_INTERNAL_DOMAIN>` | Internal/on-prem `.local` domain | `acme.local` |
| `<CUSTOMER_ADCS_HOSTNAME>` | ADCS server hostname | `adcs.acme.local` |
| `<CUSTOMER_AD_KDC>` | AD Domain Controller / KDC FQDN | `dc01.ad.acme.se` |
| `<CUSTOMER_LAB_DOMAIN>` | Lab environment domain | `k8s.lab.acme.mgmt` |
| `<NETSCALER_NSIP>` | NetScaler management/Nitro API IP | `10.0.0.32` |
| `<CLUSTER_PROD_NSVIP>` | prod cluster NetScaler internal VIP | `10.0.0.60` |
| `<CLUSTER_PROD_INTERNET_VIP>` | prod cluster NetScaler public VIP | `1.2.3.4` |
| `<CLUSTER_PROD_SNIP>` | prod cluster NetScaler SNIP | `10.0.27.5` |
| `<CLUSTER_PROD_API_SERVER_IP>` | prod Kubernetes API server IP | `10.0.27.60` |
| `<CLUSTER_TEST_NSVIP>` | test cluster NetScaler internal VIP | `10.0.0.62` |
| `<CLUSTER_TEST_INTERNET_VIP>` | test cluster NetScaler public VIP | `1.2.3.5` |
| `<CLUSTER_TEST_SNIP>` | test cluster NetScaler SNIP | `10.0.28.5` |
| `<CLUSTER_TEST_API_SERVER_IP>` | test Kubernetes API server IP | `10.0.28.60` |
| `<CLUSTER_PROD_NSVIP_RESERVED>` | prod reserved internal VIP | `10.0.0.61` |
| `<CLUSTER_TEST_NSVIP_RESERVED>` | test reserved internal VIP | `10.0.0.63` |
| `<CLUSTER_SHARED_PROD_API_SERVER_IP>` | shared-prod01 API server IP | `10.0.25.60` |
| `<CLUSTER_SHARED_TEST_API_SERVER_IP>` | shared-test01 API server IP | `10.0.26.60` |
| `<CLUSTER_SHARED_PROD_INTERNET_VIP>` | shared-prod01 internet VIP | `1.2.3.6` |
| `<CLUSTER_SHARED_TEST_INTERNET_VIP>` | shared-test01 internet VIP | `1.2.3.7` |

---

## Key Vault Secrets to Provision

Before bootstrapping, create the following secrets in `<AZURE_KEY_VAULT_NAME>`:

| Secret Name | Description |
|-------------|-------------|
| `kv-clientId` | Service principal client ID for ESO Azure auth |
| `kv-clientSecret` | Service principal client secret for ESO Azure auth |
| `argocd-sshKey-gitops` | SSH private key for GitOps repo access |
| `argocd-oidc-clientId` | OIDC client ID (Azure AD App Registration) |
| `argocd-oidc-clientSecret` | OIDC client secret |
| `argocd-cluster-platform-prod01-token` | ArgoCD ServiceAccount token for prod cluster |
| `argocd-cluster-platform-prod01-ca` | prod cluster CA certificate (base64) |
| `argocd-cluster-platform-test01-token` | ArgoCD ServiceAccount token for test cluster |
| `argocd-cluster-platform-test01-ca` | test cluster CA certificate (base64) |
| `externaldns-kerberos-username` | Kerberos service account username |
| `externaldns-kerberos-password` | Kerberos service account password |
| `netscaler-login` | NetScaler operator account password |

Use `utils/register-argocd-cluster.sh` to automatically extract and store the ArgoCD cluster credentials.

---

## Bootstrap Order

1. **Install required tools** — `setup/required-tools.sh`
2. **Configure kubeconfig** — see `bootstrap/Initial_kubeconfig.md`
3. **Bootstrap ESO auth secret** — `utils/bootstrap-secrets-platform-kv.sh platform-argocd`
4. **Deploy External Secrets Operator** — `deployments/<cluster>/external-secrets-operator/`
5. **Deploy ArgoCD** — `deployments/<cluster>/argocd/`
6. **Register clusters in ArgoCD** — `utils/register-argocd-cluster.sh <cluster-name>`
7. **Apply ArgoCD App-of-Apps** — `deployments/<cluster>/argocd-apps/`

See `bootstrap/ArgoCD.md` and `bootstrap/ESO.md` for detailed steps.

---

## Regenerating install.yaml manifests

The `deployments/*/install/install.yaml` files are pre-rendered Helm manifests. After filling in your values in `templates/*/values/`, rebuild them with:

```bash
cd templates/<component>
./build.sh <cluster-values-file>
# e.g.: ./build.sh ../../clusters/platform-prod01.yaml
```

---

## Notes on docs/ folder

The `docs/outline-*.md` files contain Swedish-language documentation templates formatted for the [Outline](https://www.getoutline.com/) wiki. They were originally created for a Swedish public sector customer and serve as a structural reference. Adapt language and content for each new customer.

To paste formatted content into Outline (WYSIWYG editor):
1. Open the `.md` file in VS Code
2. Press `Ctrl+Shift+V` to open the Markdown Preview
3. Select All + Copy from the preview
4. Paste directly into Outline — rich text formatting is preserved
