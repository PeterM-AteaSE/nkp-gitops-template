# Workshop Preparation Guide
## Kubernetes Platform GitOps Workshop

**Workshop Date:** TBD  
**Important:** Complete ALL steps before the workshop day

> **Note:** This guide is written for **Linux**. Most things work on macOS too.
> Windows users should use WSL2. Scripts in `setup/bin/` are OS-specific — if you need
> a Windows or macOS variant, add it there and keep it maintained.

---

## 1. Required Tools

You need these tools installed before the workshop. Install them yourself using the
scripts in `setup/bin/<tool>/` as a reference, or your own package manager.

| Tool | Purpose | Installer reference |
|---|---|---|
| `kubectl` | Kubernetes CLI | `setup/bin/kubectl/` |
| `helm` | Package manager | `setup/bin/helm/` |
| `ytt` | YAML templating | `setup/bin/ytt/` |
| `yq` | YAML processor | `setup/bin/yq/` |
| `jq` | JSON processor | your package manager |
| `git` | Version control | `setup/bin/git/` |
| `konfig` | Kubeconfig merging | `setup/bin/konfig/` |
| `kubectl-neat` | Clean kubectl output | `setup/bin/kubectl-neat/` |
| `kustomize` | Kubernetes manifests | `setup/bin/kustomize/` |
| `shasum` | Checksum verification | `setup/bin/shasum/` |

### Verify your tools

Once installed, run this to check everything is in place:

```bash
./setup/required-tools.sh
```

This script **only checks** — it does not install anything. Fix any missing tools before the workshop.

> **Adding tools:** If you need to add new tools to the required list, add an installer
> script in `setup/bin/<tool>/` and add the `check_binary` call in `setup/required-tools.sh`.

---

## 2. Repository Structure

Understanding this structure is the core of the workshop.

```
<GITHUB_REPO>/
├── setup/                    # Tool verification and installer references
│   ├── required-tools.sh     # Checks that required tools are installed
│   ├── helm-repo.sh          # Adds required Helm repositories
│   ├── git-hook.sh           # Installs git pre-commit hooks
│   └── bin/                  # Per-tool installer scripts (reference, not one-click)
│
├── utils/                    # Helper functions and utilities
│   ├── helpers.sh            # Sourced by all build.sh scripts
│   ├── bootstrap-secrets-platform-kv.sh  # Bootstrap initial secrets from Azure KV
│   └── rename-contexts.sh    # Rename kubeconfig contexts to friendly names
│
├── templates/                # Platform component templates (source of truth)
│   ├── argocd/
│   ├── cert-manager/
│   ├── external-secrets-operator/
│   ├── netscaler-ingress/
│   └── .../
│       ├── build.sh          # Builds manifests for a given cluster
│       └── values/           # Helm values with ytt annotations
│
├── clusters/                 # Per-cluster configuration values
│   ├── platform-prod01.yaml
│   ├── platform-test01.yaml
│   └── ...
│
└── deployments/              # Generated manifests — committed to git
    ├── platform-prod01/
    └── platform-test01/
```

**The golden rule:**
> Never edit files in `deployments/` by hand. Always change `templates/` or `clusters/` and rebuild.

---

## 3. How It Works

### The build pipeline

```
templates/<component>/values/values.yaml   (helm template)
         +
clusters/<cluster>.yaml                    (cluster-specific values)
         ↓
templates/<component>/build.sh <cluster>   (runs helm + ytt)
         ↓
deployments/<cluster>/<component>/install/install.yaml
         ↓
kubectl apply -f ...
         ↓
git commit
```

### Try it

```bash
# Configure Helm repos first (only needed once)
./setup/helm-repo.sh

# Build a component for the test cluster
cd templates/external-secrets-operator
./build.sh platform-test01

# Review what was generated
cat ../../deployments/platform-test01/external-secrets-operator/install/install.yaml
```

Read `build.sh` and understand each step — this is the pattern used by every component.

### How cluster values flow into templates

Cluster configs use plain YAML. Templates reference values using ytt syntax:

```yaml
# clusters/platform-prod01.yaml
argocd:
  server:
    serverUrl: argocd.k8s.<CUSTOMER_K8S_DOMAIN>
```

```yaml
# templates/argocd/values/values.yaml
hostname: #@ data.values.argocd.server.serverUrl
```

When `build.sh` runs, ytt replaces `#@ data.values.*` with the actual cluster values.

---

## 4. The Utils Folder

### helpers.sh

Sourced by every `build.sh`. Provides:

- `check_githook()` — enforces git hooks are installed
- `validate_args()` — validates the cluster argument
- `export_cluster_vars()` — loads `clusters/<cluster>.yaml` into environment
- `validate_helm_template()` — validates generated YAML
- `is_allowed()` — checks cluster is in the component's ALLOW_LIST

You do not call these manually — `build.sh` handles it. But understanding them helps you troubleshoot.

### bootstrap-secrets-platform-kv.sh

Used **once** when setting up a new cluster, before External Secrets Operator is running. Pulls secrets from Azure Key Vault and creates them directly in Kubernetes.

```bash
# Requires: az login + correct kubectl context
./utils/bootstrap-secrets-platform-kv.sh platform-test01
```

### rename-contexts.sh

Renames long kubeconfig context names to match our cluster naming convention.

```bash
./utils/rename-contexts.sh
# aks-platform-test01-admin-abc123 → platform-test01
```

---

## 5. Kubeconfig Setup

`konfig` is a tool for merging kubeconfig files — it's in the required tools list.

```bash
# Merge a downloaded kubeconfig into ~/.kube/config
konfig import -s <downloaded-kubeconfig>

# Rename contexts to friendly names
./utils/rename-contexts.sh

# Verify
kubectl config get-contexts
kubectl config use-context platform-test01
kubectl get nodes
```

---

## 6. Before the Workshop

That's it. Three things:

- [ ] All tools pass: `./setup/required-tools.sh`
- [ ] Repository cloned: `git clone https://github.com/<GITHUB_ORG>/<GITHUB_REPO>.git`
- [ ] Azure login works: `az login && az account show`

Everything else will be covered during the workshop.

---

*<CUSTOMER_FULLNAME> NKP Platform Team*  
*Updated: 2 March 2026*

