#!/usr/bin/env bash
cd out
for user in $(cat ../partners)
do
    export KUBECONFIG=../aces-1.conf
    ../create-kubernetes-user.sh $user

    export KUBECONFIG=../aces-2.conf
    ../create-kubernetes-user.sh $user

    export KUBECONFIG=./$user-aces-1-kubeconfig.yaml:./$user-aces-2-kubeconfig.yaml
    kubectl config view --flatten > $user-kubeconfig.yaml
done
echo Done!
