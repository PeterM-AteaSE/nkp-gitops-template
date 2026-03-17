# How to get the initial kubeconfig file

In order to access anything in NKP you need kubeconfig information for each cluster you want to work with. Initially you need the config for the management cluster, then you can use that to get to the other clusters.  

Here is how you can get the initial kubeconfig information.

* Log into the Kommander webpage [here](https://10.230.24.30/dkp/kommander/)
* Click the link for the "Kommander Host" cluster
* Click the "Dashboard" blue button under the logo
* In the dropdown box at the very top, select "default"
* In the list on the left, select "Secrets"
* In the main window, find and click the secret called "management-kubeconfig". It is usually on page 2.
* When you see the secret content, click the little eye icon in the data section to view the full content.
* Copy the content and save it to a file called simply "config". No file suffix.  
Beware that sometimes there is an extra empty space at the beginning of the file. Do NOT include that empty space!
* Move the "config" file to a folder called ".kube" that is located in the root of your home folder. The leading dot is IMPORTANT!

Once the ".kube/config" file is in place kubectl should work for you. You can test it with a simple command, example with output is below

```sh
kubectl get nodes
NAME                                STATUS   ROLES           AGE    VERSION
management-cpdl9-mwwmg              Ready    control-plane   136d   v1.33.2
management-cpdl9-qjf8h              Ready    control-plane   136d   v1.33.2
management-cpdl9-zbfmg              Ready    control-plane   136d   v1.33.2
management-md-0-t2cck-sqb4j-dpfls   Ready    <none>          136d   v1.33.2
management-md-0-t2cck-sqb4j-mplr4   Ready    <none>          104d   v1.33.2
management-md-0-t2cck-sqb4j-mt89w   Ready    <none>          136d   v1.33.2
management-md-0-t2cck-sqb4j-shs8s   Ready    <none>          104d   v1.33.2

```

## Additional cluster kubeconfigs

For this step you will need to have the NKP CLI downloaded.  
Make sure your kubectl context is set to the management cluster, or nkp commands will fail.

First, get a list of workspaces and their associated namespaces

```sh
nkp get workspaces

```

From this list, note the namespaces and deduce which cluster goes with each namespace.  
Now run the below command template for cluster and its accosiated namespace.

```sh
export NAMESPACE=<the cluster namespace>
export CLUSTER=<the cluster name>
nkp get kubeconfig -n $NAMESPACE -c $CLUSTER > $CLUSTER.yaml

```

Once you have the kubeconfig of all the clusters, use a tool like "konfig" or "kubecm" to add/merge them to your .kube/config file.  
Now, you can run a utility script to rename the contexts to a more usable, agreed upon shorthand names.

```sh
# From the top folder of the git repo
./setup/rename-contexts.sh

```
