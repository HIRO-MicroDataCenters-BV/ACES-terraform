# ACES clusters Terraform

This config creates two clusters in the same on AWS on top EC2 instances using `kubeadm`.

The kubeconfig files for the individual clusters will be saved in the current working directory with a name corresponding to the cluster they belong to.

Keep in mind that the tf script is only for initial setup of the cluster. Changing cluster configuration (like adding more nodes) should be done manually since tf will just destroy and recreate EC2 instances.

## Requirements

This need to be installed locally:
- terraform
- awscli => 2.x
- kubectl => 1.27
- helm >= 3.x
- openssh (your local ssh key `~/.ssh/id_rsa` will be use to access the clusters)

Your AWS account must be configure. If it is not the case already, use `aws configure`.

## Usage

Look at the main.tf file to check parameters.

Then apply with:
```sh
terraform init
terraform apply
```
The Kubernetes clusters are set and can be accessed with:
```sh
export KUBCONFIG=./aces-1.conf
kubectl get nodes
```

## Post install

### Extend instance root storage

By default T3 instances have only 10GB of storage. Extend it at least to 150GB before running workloads on cluster.

### Manually attach Submariner security group to nodes

Submariner security group is not attached automatically to nodes. Do it manually via AWS console or AWS CLI.

### Rename and merge KUBECONFIG

In both `aces-*.conf` rename context, user and cluster the aces-1 or aces-2
depending on the cluster.
```
export KUBECONFIG=./aces-1.conf:./aces-2.conf
kubectl config view --flatten > kubeconfig.yaml
```

### CNI

Install The Flannel CNI on both clusters
```sh
helm repo add flannel https://flannel-io.github.io/flannel/

export KUBECONFIG=aces-1.conf
kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged
helm install flannel --set podCidr="10.42.0.0/16" --namespace kube-flannel flannel/flannel

export KUBECONFIG=aces-2.conf
kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged
helm install flannel --set podCidr="10.0.0.0/16" --namespace kube-flannel flannel/flannel
```

### Submariner

Now you can install submariner CLI `subctl` with:
```sh
curl -Ls https://get.submariner.io | VERSION=0.17.0 bash
export PATH=$PATH:~/.local/bin
```

Now will use aces-1 as a Submariner broker:
```
subctl deploy-broker --kubeconfig aces-1.conf --namespace submariner
```

And finally join the other cluster with:
```sh
subctl join --kubeconfig aces-1.conf broker-info.subm --clusterid aces-1
# Choose master as the gateway
subctl join --kubeconfig aces-2.conf broker-info.subm --clusterid aces-2
# Choose master as the gateway
```

Now that the installation is done you can verify the connectivity with:
```sh
export KUBECONFIG=aces-1.conf:aces-2.conf
subctl verify --context aces-1 --tocontext aces-2 --only service-discovery,connectivity --verbose
```


### AWS EBS CSI for volumes
  1. Get AWS EBS CSI [driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md)
  2. Edit values.yaml to add default `storageClass`
    ```yaml
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
    name: gp2
    annotations:
        storageclass.kubernetes.io/is-default-class: "true"
    provisioner: ebs.csi.aws.com
    parameters:
    type: gp2
    reclaimPolicy: Delete
    allowVolumeExpansion: true
    volumeBindingMode: WaitForFirstConsumer
    allowedTopologies:
    - matchLabelExpressions:
    - key: topology.ebs.csi.aws.com/zone
        values:
        - eu-west-3c
    ```

  3. Install the driver with an updated `values.yaml`

> TODO: Add the EBS CSI driver installation to the terraform script
## Features

- [X] Two Kubernetes 1.29 clusters
- [X] Flanel CNI
- [X] Submariner
- [X] AWS EBS CSI for volumes 


## Create Access for users

To create one namespace per partner and give them access to both clusters run the `create-users.sh` script.
Partners listed in the `./partners` file.

All partners config with both cluster credentials in it, named `<partner name>-kubeconfig.yaml` should be available in the current directory.

To give more rights to one partner just change its Role assignment to a more permissive one in both clusters.

