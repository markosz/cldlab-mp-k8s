#!/usr/bin/env bash

set -euxo pipefail


: ${KUBERNETES_DISTRIBUTION:='microk8s'}

: ${CPU:=4}
: ${MEM:=8G}
: ${DISK:=50G}
: ${INSTANCE_NAME:=singlenode-uk8s}

#############

mkdir -p ${HOME}/.kube

multipass launch --name $INSTANCE_NAME --cpus $CPU --mem $MEM --disk $DISK

multipass exec $INSTANCE_NAME -- /bin/bash -c "sudo snap install microk8s --classic"
multipass exec $INSTANCE_NAME -- /bin/bash -c "sudo usermod -a -G microk8s ubuntu"

multipass exec $INSTANCE_NAME -- /bin/bash -c /snap/bin/microk8s.config > ${HOME}/.kube/single-microk8s.yaml

multipass exec $INSTANCE_NAME -- /bin/bash -c "/snap/bin/microk8s enable dns"
multipass exec $INSTANCE_NAME -- /bin/bash -c "/snap/bin/microk8s enable registry"
