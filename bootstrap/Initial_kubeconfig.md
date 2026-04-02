# How to get the initial kubeconfig file

In order to access anything in Kubernetes you need kubeconfig information for each cluster you want to work with. How you obtain kubeconfigs depends on your Kubernetes distribution (Nutanix NKP, Rancher, EKS, etc.).

## Generic approach

Most distributions provide kubeconfig download via their UI or CLI. Once you have the kubeconfig file for each cluster, save it and merge it into your `~/.kube/config` using a tool like `konfig` or `kubecm`:

```bash
# Example: merge a downloaded kubeconfig
kubecm add -f <cluster>.yaml
# or
konfig import <cluster>.yaml
```

## Additional cluster kubeconfigs

Once you have kubeconfigs for all clusters, use a utility script to rename the contexts to a more usable shorthand:

```bash
# From the top folder of the git repo
./setup/rename-contexts.sh
```

```
