# External Secrets with JSON Configuration Guide

This guide demonstrates different approaches for creating Kubernetes secrets with JSON documents using External Secrets Operator (ESO) and Azure Key Vault.

## Overview

External Secrets Operator can create secrets containing JSON documents where values are dynamically pulled from Azure Key Vault. This is useful for application configuration files, service account keys, or complex configuration structures.

## Prerequisites

- External Secrets Operator installed in cluster
- SecretStore configured for Azure Key Vault (e.g., `eso-store-platform`)
- Appropriate secrets stored in Azure Key Vault: `<AZURE_KEY_VAULT_NAME>`

---

## Approach 1: Template JSON from Multiple Key Vault Secrets

**Use Case:** When you need to construct a JSON configuration from multiple separate secrets stored in Azure Key Vault.

**Advantages:**
- Fine-grained control over individual secret values
- Easy to update individual values in Key Vault
- Clear separation of concerns (each credential is a separate Key Vault secret)
- Allows mixing static configuration with dynamic secrets

**Example: ArgoCD Dex OIDC Configuration**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: es-argocd-dex-config
  namespace: platform-argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: eso-store-platform
    kind: SecretStore
  target:
    name: argocd-dex-config
    creationPolicy: Owner
    template:
      data:
        # Create dex.config as a JSON document
        dex.config: |
          {
            "connectors": [
              {
                "type": "oidc",
                "id": "azure-ad",
                "name": "Azure AD",
                "config": {
                  "issuer": "https://login.microsoftonline.com/<AZURE_TENANT_ID>/v2.0",
                  "clientID": "{{ .clientId }}",
                  "clientSecret": "{{ .clientSecret }}",
                  "redirectURI": "https://argocd.<CUSTOMER_DOMAIN>/api/dex/callback"
                }
              }
            ]
          }
  data:
    - secretKey: clientId
      remoteRef:
        key: argocd-oidc-clientId
    - secretKey: clientSecret
      remoteRef:
        key: argocd-oidc-clientSecret
```

**Azure Key Vault Secrets Required:**
- `argocd-oidc-clientId` → `12345678-1234-1234-1234-123456789abc`
- `argocd-oidc-clientSecret` → `secret-value-here`

**Resulting Kubernetes Secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-dex-config
  namespace: platform-argocd
type: Opaque
data:
  dex.config: <base64-encoded-json>
```

---

## Approach 2: Store Complete JSON in Key Vault

**Use Case:** When you have a pre-formatted JSON configuration that doesn't need templating.

**Advantages:**
- Simpler ExternalSecret definition
- JSON structure managed in Azure Key Vault
- Good for migrating existing configurations
- No templating overhead

**Disadvantages:**
- Harder to update individual values
- Less visibility into what's in the JSON without checking Key Vault
- Can't mix static and dynamic content easily

**Example: Application Configuration**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: es-app-config
  namespace: my-application
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: eso-store-platform
    kind: SecretStore
  target:
    name: app-config
    creationPolicy: Owner
  data:
    - secretKey: config.json
      remoteRef:
        key: my-app-complete-config
```

**Azure Key Vault Secret:**

Key: `my-app-complete-config`

Value:
```json
{
  "database": {
    "host": "postgres.example.com",
    "port": 5432,
    "username": "appuser",
    "password": "secret-password"
  },
  "apiEndpoints": {
    "primary": "https://api.<CUSTOMER_DOMAIN>",
    "backup": "https://api-backup.<CUSTOMER_DOMAIN>"
  }
}
```

---

## Approach 3: Hybrid - Mix Static and Dynamic Content

**Use Case:** When you have stable configuration mixed with sensitive credentials.

**Advantages:**
- Best of both worlds
- Static configuration visible in Git
- Sensitive values from Key Vault
- Easy to understand what's configured
- Changes to static values don't require Key Vault access

**Example: Service Account with Mixed Configuration**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: es-service-account-config
  namespace: my-application
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: eso-store-platform
    kind: SecretStore
  target:
    name: service-account-config
    creationPolicy: Owner
    template:
      data:
        credentials.json: |
          {
            "type": "service_account",
            "project_id": "<CUSTOMER_SHORT>-platform",
            "private_key_id": "{{ .privateKeyId }}",
            "private_key": "{{ .privateKey }}",
            "client_email": "service@<CUSTOMER_SHORT>-platform.iam.gserviceaccount.com",
            "client_id": "{{ .clientId }}",
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs"
          }
  data:
    - secretKey: privateKeyId
      remoteRef:
        key: service-account-private-key-id
    - secretKey: privateKey
      remoteRef:
        key: service-account-private-key
    - secretKey: clientId
      remoteRef:
        key: service-account-client-id
```

**Azure Key Vault Secrets Required:**
- `service-account-private-key-id` → `abc123def456`
- `service-account-private-key` → `-----BEGIN PRIVATE KEY-----\n...`
- `service-account-client-id` → `987654321`

---

## Approach 4: Complex Nested JSON with Multiple Values

**Use Case:** Application configuration with deeply nested structures and multiple secret sources.

**Advantages:**
- Handles complex configuration requirements
- Supports arrays and nested objects
- All secrets managed as separate Key Vault entries

**Example: Ollama Configuration with Multiple API Keys**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: es-ollama-config
  namespace: platform-ai
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: eso-store-platform
    kind: SecretStore
  target:
    name: ollama-config
    creationPolicy: Owner
    template:
      data:
        config.json: |
          {
            "server": {
              "host": "0.0.0.0",
              "port": 11434,
              "enableMetrics": true
            },
            "models": {
              "defaultModel": "llama2",
              "cacheDir": "/models"
            },
            "integrations": {
              "openai": {
                "enabled": true,
                "apiKey": "{{ .openaiApiKey }}"
              },
              "azure": {
                "enabled": true,
                "endpoint": "https://<CUSTOMER_SHORT>-ai.openai.azure.com/",
                "apiKey": "{{ .azureApiKey }}",
                "deployment": "gpt-4"
              }
            },
            "security": {
              "adminToken": "{{ .adminToken }}",
              "allowedOrigins": [
                "https://ai.<CUSTOMER_DOMAIN>",
                "https://chat.<CUSTOMER_DOMAIN>"
              ]
            }
          }
  data:
    - secretKey: openaiApiKey
      remoteRef:
        key: ollama-openai-api-key
    - secretKey: azureApiKey
      remoteRef:
        key: ollama-azure-api-key
    - secretKey: adminToken
      remoteRef:
        key: ollama-admin-token
```

---

## Approach 5: Multi-File Secrets with JSON

**Use Case:** When you need multiple configuration files in one secret (e.g., for volume mounts).

**Advantages:**
- Single ExternalSecret creates multiple files
- Good for applications expecting mounted configuration files
- Clear file naming

**Example: External DNS Configuration**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: es-external-dns-config
  namespace: platform-networking
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: eso-store-platform
    kind: SecretStore
  target:
    name: external-dns-config
    creationPolicy: Owner
    template:
      data:
        # First config file
        azure-config.json: |
          {
            "tenantId": "<AZURE_TENANT_ID>",
            "subscriptionId": "{{ .subscriptionId }}",
            "resourceGroup": "rg-nkp-platform",
            "aadClientId": "{{ .clientId }}",
            "aadClientSecret": "{{ .clientSecret }}"
          }
        # Second config file
        dns-zones.json: |
          {
            "zones": [
              "<CUSTOMER_DOMAIN>",
              "platform.<CUSTOMER_DOMAIN>"
            ],
            "policy": "sync",
            "txtOwnerId": "external-dns-platform"
          }
        # Plain text credential
        api-token: "{{ .apiToken }}"
  data:
    - secretKey: subscriptionId
      remoteRef:
        key: azure-subscription-id
    - secretKey: clientId
      remoteRef:
        key: external-dns-client-id
    - secretKey: clientSecret
      remoteRef:
        key: external-dns-client-secret
    - secretKey: apiToken
      remoteRef:
        key: external-dns-api-token
```

---

## Advanced Templating Features

### Escaping Special Characters in JSON

When values contain quotes or special characters:

```yaml
template:
  data:
    config.json: |
      {
        "description": "User's configuration",
        "path": "C:\\Program Files\\App",
        "value": {{ .secretValue | quote }}
      }
```

### Using Template Functions

External Secrets supports Go template functions:

```yaml
template:
  data:
    config.json: |
      {
        "timestamp": "{{ now | date "2006-01-02T15:04:05Z07:00" }}",
        "upperCaseValue": "{{ .value | upper }}",
        "base64Encoded": "{{ .secret | b64enc }}"
      }
```

### Conditional Values

```yaml
template:
  data:
    config.json: |
      {
        "environment": "{{ .environment }}",
        {{- if eq .environment "production" }}
        "logLevel": "warn",
        {{- else }}
        "logLevel": "debug",
        {{- end }}
        "apiKey": "{{ .apiKey }}"
      }
```

---

## Decision Matrix

| Approach | Best For | Complexity | Flexibility | Maintainability |
|----------|----------|------------|-------------|-----------------|
| **Approach 1: Template from Multiple Secrets** | Most applications | Medium | High | High ⭐ |
| **Approach 2: Complete JSON in Vault** | Simple migrations | Low | Low | Medium |
| **Approach 3: Hybrid Static/Dynamic** | Service accounts, well-defined schemas | Medium | High | High ⭐ |
| **Approach 4: Complex Nested JSON** | Advanced configurations | High | High | Medium |
| **Approach 5: Multi-File Secrets** | File-based config apps | Medium | High | High |

---

## Recommendations

### For New Applications
**Use Approach 1 or 3** - Template-based with separate Key Vault secrets for each credential.

### For Existing Applications
**Use Approach 2** - If you already have JSON configs, store them as-is in Key Vault initially, then migrate to templating if needed.

### For Complex Integrations
**Use Approach 4** - When dealing with multiple services and nested configuration structures.

### For Config-File-Based Apps
**Use Approach 5** - When applications expect mounted configuration files.

---

## Testing Your Configuration

After creating an ExternalSecret, verify it works:

```bash
# Check ExternalSecret status
kubectl get externalsecret -n <namespace>

# Describe to see any errors
kubectl describe externalsecret es-<name> -n <namespace>

# View the created secret
kubectl get secret <secret-name> -n <namespace> -o yaml

# Decode and view the JSON content
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.config\.json}' | base64 -d | jq .
```

---

## Common Issues and Solutions

### Issue: Template syntax errors

**Symptom:** ExternalSecret shows error status

**Solution:** Validate JSON syntax and template variables. Use a JSON validator and ensure all `{{ .variables }}` are defined in the `data` section.

### Issue: Values not refreshing

**Symptom:** Updated Key Vault values not reflected in secret

**Solution:** Check `refreshInterval` setting or delete the secret to force recreation:
```bash
kubectl delete secret <secret-name> -n <namespace>
```

### Issue: Special characters breaking JSON

**Symptom:** Invalid JSON in resulting secret

**Solution:** Use the `quote` template function for string values:
```yaml
"value": {{ .secretValue | quote }}
```

---

## Next Steps

1. Review these approaches with your team/customer
2. Identify which secrets need JSON configuration
3. Decide on the appropriate approach based on requirements
4. Create the necessary secrets in Azure Key Vault
5. Implement and test the ExternalSecret resources

## References

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Template Syntax](https://external-secrets.io/latest/guides/templating/)
- [Azure Key Vault Provider](https://external-secrets.io/latest/provider/azure-key-vault/)
