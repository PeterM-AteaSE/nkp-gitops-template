#!/bin/bash
# Usage: bootstrap-secrets-platform-kv.sh <namespace>
# Example: bootstrap-secrets-platform-kv.sh platform-externaldns

NAMESPACE="${1:?Usage: $0 <namespace>}"

export ID=$(az keyvault secret show --vault-name <AZURE_KEY_VAULT_NAME> --name kv-clientId --query value -o tsv)
export PW=$(az keyvault secret show --vault-name <AZURE_KEY_VAULT_NAME> --name kv-clientSecret --query value -o tsv)

export YAMLFILE=/tmp/tempfile.yaml
cat >$YAMLFILE <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: eso-azure-auth
  namespace: $NAMESPACE
stringData:
  clientId: $ID
  clientSecret: $PW
EOF

kubectl apply -f $YAMLFILE
rm $YAMLFILE
