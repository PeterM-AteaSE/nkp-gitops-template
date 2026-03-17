# ADCS Issuer

Deploys [djkormo/adcs-issuer](https://github.com/djkormo/adcs-issuer) — a cert-manager external issuer that requests certificates from Microsoft Active Directory Certificate Services (ADCS).

## Prerequisites

### 1. Add ADCS credentials to Azure Key Vault

Two secrets must exist in `<AZURE_KEY_VAULT_NAME>` before the build is run:

| Key Vault secret name          | Description                          |
|-------------------------------|--------------------------------------|
| `adcs-credentials-username`   | ADCS service account (`DOMAIN\user`) |
| `adcs-credentials-password`   | ADCS service account password        |

```bash
az keyvault secret set --vault-name <AZURE_KEY_VAULT_NAME> \
  --name adcs-credentials-username --value "DOMAIN\\adcs-svc"

az keyvault secret set --vault-name <AZURE_KEY_VAULT_NAME> \
  --name adcs-credentials-password --value "<password>"
```

### 2. Bootstrap the ESO auth secret in the new namespace

The External Secrets Operator needs an `eso-azure-auth` secret in `platform-adcs-issuer` to authenticate against Azure Key Vault:

```bash
utils/bootstrap-secrets-platform-kv.sh platform-adcs-issuer
```

### 3. Verify ADCS server URL in cluster config

Check that `adcs.url` in the cluster YAML points to the correct ADCS enrollment endpoint:

- [clusters/platform-prod01.yaml](../../clusters/platform-prod01.yaml)
- [clusters/platform-test01.yaml](../../clusters/platform-test01.yaml)

```yaml
adcs:
  url: "https://<CUSTOMER_ADCS_HOSTNAME>/certsrv"   # <-- update if needed
  templateName: "WebServer"
  statusCheckInterval: "6h"
  retryInterval: "1h"
```

### 4. Ensure cert-manager is running

cert-manager must be fully deployed and healthy before the ADCS issuer is applied:

```bash
kubectl wait --for=condition=Ready pod \
  -n platform-cert-manager \
  -l app.kubernetes.io/name=cert-manager \
  --timeout=300s
```

---

## Build & deploy

```bash
# Build manifests
cd templates/adcs-issuer
./build.sh platform-prod01

# Register the ArgoCD Application
cd templates/argocd-apps
./build.sh platform-prod01

# Commit and push — ArgoCD will sync automatically
git add ../../deployments/platform-prod01/adcs-issuer \
        ../../deployments/platform-prod01/argocd-apps/adcs-issuer
git commit -m "feat(adcs-issuer): build manifests for platform-prod01"
git push
```

Or apply directly without GitOps:

```bash
kubectl apply -f ../../deployments/platform-prod01/adcs-issuer/ --recursive
```

---

## Verify

```bash
# Controller pod
kubectl get pods -n platform-adcs-issuer

# Wait for ready
kubectl wait --for=condition=Ready pod \
  -n platform-adcs-issuer \
  -l app.kubernetes.io/name=adcs-issuer \
  --timeout=300s

# CRDs installed
kubectl get crd | grep adcs

# ClusterAdcsIssuer status
kubectl get clusteradcsissuer hbg-adcs-issuer -o yaml

# ESO synced the credentials secret
kubectl get secret adcs-credentials -n platform-adcs-issuer

# Controller logs
kubectl logs -n platform-adcs-issuer -l app.kubernetes.io/name=adcs-issuer --tail=40
```

---

## Issue a test certificate

Apply [clusterissuers/example-certificate.yaml](clusterissuers/example-certificate.yaml) after updating the `commonName` and `dnsNames` fields, then check its status:

```bash
kubectl get certificate example-adcs-certificate -n default
kubectl describe certificaterequest -n default
```
