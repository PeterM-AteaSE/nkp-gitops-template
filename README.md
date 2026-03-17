# HBG Nutanix Kubernetes Platform - GitOps

This repository manages the infrastructure and configuration for HBG's Nutanix Kubernetes Platform (NKP) clusters using GitOps principles.

## Overview

This repository provides automated tooling, configuration templates, and bootstrap procedures for managing Kubernetes platform clusters with integrated Citrix/Netscaler load balancing.

## Repository Structure

```
├── bootstrap/          # Step-by-step bootstrap procedures for new clusters
├── clusters/           # Cluster-specific configuration files
├── deployments/        # Generated manifests for each cluster/application
├── setup/              # Tool installation scripts and automation
│   └── bin/           # Individual tool installers (kubectl, helm, etc.)
├── templates/          # Application templates and build scripts
│   ├── adcs-issuer/
│   ├── argocd/
│   ├── cert-manager/
│   ├── externaldns-internal/
│   ├── netscaler-ingress/
│   └── olmv0/
└── utils/             # Helper scripts and utilities
```

## Prerequisites

Before working with this repository, ensure you have:

- Linux-based system (Debian/Fedora supported)
- Root or sudo access for tool installation
- Access to target Kubernetes clusters
- Network access to Citrix Netscaler infrastructure

## Getting Started

### 1. Install Required Tools

Run the automated tool installation script:

```bash
./setup/required-tools.sh
```

This installs essential tools including:
- kubectl - Kubernetes CLI
- helm - Package manager for Kubernetes
- kustomize - Template-free customization of Kubernetes manifests
- kubeseal - Sealed Secrets encryption tool
- yq - YAML processor
- ytt - YAML templating tool (Carvel)
- kubectl-neat - Clean Kubernetes manifests
- konfig - Kubeconfig manager
- cmctl - cert-manager CLI
- mc - MinIO client

### 2. Configure Git Hooks

Configure git hooks for commit message validation:

```bash
git config core.hooksPath .githooks
```

### 3. Rename Kubectl Contexts (Optional)

For easier cluster management, rename your kubectl contexts to shorter aliases:

```bash
./setup/rename-contexts.sh
```

This script renames contexts from the default long names to shorter, more convenient aliases:

- `hbg-platform-prod01-admin@hbg-platform-prod01` → `platform-p01`
- `hbg-platform-test01-admin@hbg-platform-test01` → `platform-t01`
- `hbg-shared-prod01-admin@hbg-shared-prod01` → `shared-p01`
- `hbg-shared-test01-admin@hbg-shared-test01` → `shared-t01`
- `management-admin@management` → `nkp-admin`

After renaming, you can switch contexts more easily:

```bash
kubectl config use-context platform-t01
# or use kubectx if installed
kubectx platform-p01
```

### 4. Add Helm Repositories

Add required Helm repositories for applications:

```bash
# External DNS
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/

# Netscaler Ingress Controller
helm repo add netscaler https://netscaler.github.io/netscaler-helm-charts/

# cert-manager
helm repo add jetstack https://charts.jetstack.io

# ADCS Issuer (Microsoft Active Directory Certificate Services)
helm repo add djkormo-adcs-issuer https://djkormo.github.io/adcs-issuer/

# External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io

# Ollama (Local LLM inference)
helm repo add otwld https://helm.otwld.com/

# Open WebUI (LLM web interface)
helm repo add open-webui https://helm.openwebui.com/

# Update repositories
helm repo update
```

### 5. Configure Cluster Settings

Cluster configurations are stored in the `clusters/` directory. Each cluster has:

- Cluster name and environment type (test/prod)
- Citrix Ingress Controller (CIC) settings
- Netscaler IP addresses and VIPs
- Network configuration for policy-based routing

Example cluster configuration structure:

```yaml
name: hbg-platform-test01
env: test
cic:
  nsIP: x.x.x.x          # Netscaler admin address
  nsVIP: x.x.x.x         # Internal services VIP
  nsInternetVIP: x.x.x.x # Public services VIP
  nsSNIPS: x.x.x.x       # Subnet IP for PBR
```

## Building Applications

Each application in `templates/` has its own build script that generates Kubernetes manifests for specific clusters.

### Available Applications

- **adcs-issuer** - Microsoft Active Directory Certificate Services issuer for cert-manager
- **argocd** - GitOps continuous delivery tool (operator-based deployment, WIP)
- **cert-manager** - Certificate management for Kubernetes
- **external-secrets-operator** - Synchronize secrets from external secret management systems
- **externaldns-internal** - Automatic DNS records for internal services
- **netscaler-ingress** - Citrix Netscaler Ingress Controller
- **ollama** - Local LLM inference engine
- **olmv0** - Operator Lifecycle Manager
- **open-webui** - Web interface for LLM interaction

### Building for a Cluster

Navigate to the application template directory and run the build script with the cluster name:

```bash
# Example: Build externaldns-internal for platform-test01
cd templates/externaldns-internal
./build.sh platform-test01

# Example: Build cert-manager for platform-prod01
cd templates/cert-manager
./build.sh platform-prod01
```

### Build Output

Generated manifests are placed in `deployments/<cluster>/<application>/`:

```
deployments/
└── platform-test01/
    ├── cert-manager/
    │   ├── install/
    │   └── issuers/
    ├── externaldns-internal/
    │   └── install/
    └── netscaler-ingress/
        ├── install/
        └── config/
```

### Application Build Process

Each build script:

1. **Validates** - Checks cluster name against allowed list
2. **Exports variables** - Sets cluster-specific configuration
3. **Creates directories** - Prepares deployment structure
4. **Templates Helm charts** - Generates Kubernetes manifests with cluster-specific values
5. **Applies customizations** - Runs cluster-specific build functions
6. **Validates output** - Ensures generated YAML is valid

### Customizing Builds

Each application has a `values/values.yaml` file for default Helm values. Cluster-specific customizations are handled in the `build_<cluster>()` functions within each `build.sh` script.

Example structure of a build script:

```bash
APP_NAME="cert-manager"
HELM_CHART_VERSION="1.16.2"
HELM_REPOSITORY="jetstack/cert-manager"
NAMESPACE="platform-cert-manager"

ALLOW_LIST=(
  "platform-test01"
  "platform-prod01"
  "delad-test01"
  "delad-prod01"
)

# Cluster-specific customizations
build_platform-test01() {
  # Use Let's Encrypt staging for test
  true
}

build_platform-prod01() {
  # Use Let's Encrypt production
  true
}
```

## Documentation

### Comprehensive Guides

- **[External Secrets JSON Guide](docs/guides/EXTERNAL_SECRETS_JSON_GUIDE.md)** - Complete guide for creating secrets with JSON documents using External Secrets Operator
- **[ArgoCD Cluster Registration](docs/ARGOCD_CLUSTER_REGISTRATION_PROPOSAL.md)** - Automated cluster registration with External Secrets and Azure Key Vault
- **[Cluster Secrets Documentation](templates/argocd/secrets/CLUSTER_SECRETS_README.md)** - Step-by-step guide for ArgoCD cluster secrets

### Bootstrap Procedures

Follow the bootstrap documentation to set up a new platform cluster:

1. **[Initial Kubeconfig Setup](bootstrap/Initial_kubeconfig.md)**
   - Get kubeconfig from management cluster
   - Configure kubectl access

2. **[External Secrets Operator](bootstrap/ESO.md)**
   - Bootstrap ESO installation
   - Configure Azure Key Vault integration

3. **[ArgoCD Setup](bootstrap/ArgoCD.md)**
   - Deploy ArgoCD with OIDC
   - Register managed clusters

## Automation Scripts

### ArgoCD Cluster Registration

Automate cluster registration with token or certificate-based authentication:

```bash
cd templates/argocd/secrets

# Token-based authentication (default)
./create-cluster-secret.sh platform-prod01 platform-prod01-admin default token

# Certificate-based authentication
./create-cluster-secret.sh my-cluster my-context platform cert
```

See [ARGOCD_CLUSTER_REGISTRATION_PROPOSAL.md](docs/ARGOCD_CLUSTER_REGISTRATION_PROPOSAL.md) for details.

## Tool Scripts

Individual tool installers are located in `setup/bin/` and organized by tool name. Each directory contains:

- Installation scripts (OS-specific or from GitHub releases)
- Release documentation
- Version references

This modular approach allows selective installation or updates of specific tools.

## Helper Utilities

The `utils/` directory contains shared helper functions used across installation scripts.

## GitOps Workflow

This repository follows GitOps principles:

1. All cluster configuration is version-controlled in Git
2. Application manifests are generated using build scripts
3. Changes are applied through Git commits and pull requests
4. Cluster state is declarative and reproducible
5. Infrastructure as Code enables automated deployments

### Typical Workflow

1. **Update configuration** - Modify cluster config or application values
2. **Build manifests** - Run build script for target cluster
3. **Review changes** - Inspect generated manifests in `deployments/`
4. **Apply to cluster** - Deploy using kubectl or GitOps tool
5. **Commit to Git** - Version control the changes

```bash
# Example workflow
cd templates/cert-manager
./build.sh platform-test01
kubectl apply -f ../../deployments/platform-test01/cert-manager/ --recursive
git add deployments/platform-test01/cert-manager/
git commit -m "Update cert-manager for platform-test01"
```

## Contributing

When adding new cluster configurations or updating tools:

1. Create a feature branch
2. Make your changes
3. Build and test manifests
4. Review generated YAML files
5. Submit a pull request for review

### Adding a New Application

To add a new application template:

1. Create directory: `templates/<app-name>/`
2. Add `build.sh` script (use existing apps as template)
3. Create `values/values.yaml` for Helm values
4. Add cluster names to `ALLOW_LIST`
5. Implement cluster-specific `build_<cluster>()` functions
6. Test the build script

### Adding a New Cluster

To add a new cluster:

1. Create cluster config: `clusters/<cluster-name>.yaml`
2. Add cluster to `ALLOW_LIST` in relevant application build scripts
3. Implement `build_<cluster-name>()` functions for cluster-specific customizations
4. Test builds for all required applications

## Maintenance

- Regularly review and update tool versions
- Keep OLM and operators up to date
- Document any manual steps in the bootstrap process
- Maintain cluster configurations as infrastructure evolves

## Support

For issues or questions regarding cluster management, consult the internal HBG Kubernetes platform team.