#!/usr/bin/env bash

set -euxo pipefail

: ${MASTER_NODE_COUNT:=1}
: ${MASTER_NODE_PREFIX:=master}

: ${WORKER_NODE_COUNT:=2}
: ${WORKER_NODE_PREFIX:=worker}

: ${KUBERNETES_DISTRIBUTION:='microk8s'}

: ${CPU:=4}
: ${MEM:=8G}
: ${DISK:=30G}

#############


function multipass_instance_exists(){
  INSTANCE_NAME=$1
  AVALIABLE_INSTANCES=(`multipass list | awk '{print $1}' | sed 1d`)
  
  for AVALIABLE_INSTANCE in "${AVALIABLE_INSTANCES[@]}"; do
    if [ "$AVALIABLE_INSTANCE" == "$INSTANCE_NAME" ]; then 
      return 1
    fi
  done
}

function create_master_node() {
  for ((counter=1; counter<=$MASTER_NODE_COUNT; counter++)); do
    MASTER_NODE_NAME=$1
    multipass launch --name $MASTER_NODE_NAME --cpus $CPU --mem $MEM --disk $DISK
  done
}

function get_master_address() {
  echo "https://$(multipass info $MASTER_NODE_NAME | grep "IPv4" | awk -F' ' '{print $2}'):6443"
}

function get_master_token() {
  if [ "$KUBERNETES_DISTRIBUTION" == "k3s" ]; then
    echo "$(multipass exec $MASTER_NODE_NAME -- /bin/bash -c "sudo cat /var/lib/rancher/k3s/server/node-token")"
  elif [ "$KUBERNETES_DISTRIBUTION" == "microk8s" ]; then
    #echo "$(multipass exec ${MASTER_NODE_NAME} -- /snap/bin/microk8s.add-node | grep "Join node with" | awk -F 'Join node with: ' '{ print $2 }' | awk -F ' ' '{ print $3}' | tr -d '\r')"
    echo "$(multipass exec ${MASTER_NODE_NAME} -- /snap/bin/microk8s.add-node | grep -m 1 "microk8s join " | awk -F ' ' '{ print $3}' | tr -d '\r')"
  fi
}

function create_worker_node() {
  WORKER_NODE_NAME=$1
  multipass launch --name $WORKER_NODE_NAME --cpus $CPU --mem $MEM --disk $DISK
}

function deploy_kubernetes_distribution() {
  NODE_TYPE=$1
  INSTANCE_NAME=$2
  
  if [ "$KUBERNETES_DISTRIBUTION" == "k3s" ]; then
    if [ "$NODE_TYPE" == "master" ]; then
      deploy_k3s_distribution_master $INSTANCE_NAME
      sleep 10s
    elif [ "$NODE_TYPE" == "worker" ]; then
      deploy_k3s_distribution_worker $INSTANCE_NAME
    fi
  elif [ "$KUBERNETES_DISTRIBUTION" == "microk8s" ]; then
    if [ "$NODE_TYPE" == "master" ]; then
      deploy_microk8s_distribution_master $INSTANCE_NAME
      sleep 10s
    elif [ "$NODE_TYPE" == "worker" ]; then
      deploy_microk8s_distribution_worker $INSTANCE_NAME
    fi
  fi
}

function deploy_k3s_distribution_master() {
  INSTANCE_NAME=$1
  multipass exec $INSTANCE_NAME -- /bin/bash -c "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -"
}

function deploy_k3s_distribution_worker() {
  INSTANCE_NAME=$1
  MASTER_NODE_URL=`get_master_address`
  MASTER_NODE_TOKEN=`get_master_token`

  multipass exec $INSTANCE_NAME -- /bin/bash -c "curl -sfL https://get.k3s.io | K3S_TOKEN=${MASTER_NODE_TOKEN} K3S_URL=${MASTER_NODE_URL} sh -"
}

function deploy_microk8s_distribution_master() {
  INSTANCE_NAME=$1

  multipass exec $INSTANCE_NAME -- /bin/bash -c "sudo snap install microk8s --classic" # --channel=1.17/stable"
  multipass exec $INSTANCE_NAME -- /bin/bash -c "sudo usermod -a -G microk8s ubuntu"
}

function deploy_microk8s_distribution_worker() {
  INSTANCE_NAME=$1
  MASTER_NODE_TOKEN=`get_master_token`

  multipass exec $INSTANCE_NAME -- /bin/bash -c "sudo snap install microk8s --classic" #--channel=1.17/stable"
  multipass exec $INSTANCE_NAME -- /bin/bash -c "sudo usermod -a -G microk8s ubuntu"
  multipass exec $INSTANCE_NAME -- /bin/bash -c "/snap/bin/microk8s.join ${MASTER_NODE_TOKEN}"
}

function copy_config_file() {
  mkdir -p ${HOME}/.kube
  INSTANCE_NAME=$1
  
  if [ "$KUBERNETES_DISTRIBUTION" == "k3s" ]; then
    MASTER_NODE_URL=`get_master_address`

    multipass exec $INSTANCE_NAME -- /bin/bash -c "cat /etc/rancher/k3s/k3s.yaml" > ${HOME}/.kube/k3s.yaml
    sed -ie s,https://127.0.0.1:6443,${MASTER_NODE_URL},g ${HOME}/.kube/k3s.yaml
  elif [ "$KUBERNETES_DISTRIBUTION" == "microk8s" ]; then
    multipass exec $INSTANCE_NAME -- /bin/bash -c /snap/bin/microk8s.config > ${HOME}/.kube/microk8s.yaml
  fi
}

function deploy_and_configure_nodes() {
  FIRST_MASTER_NOME="$MASTER_NODE_PREFIX-1"

  # Deploy and configure MASTER nodes
  for ((counter=1; counter<=$MASTER_NODE_COUNT; counter++))
  do
    MASTER_NODE_NAME=$MASTER_NODE_PREFIX-$counter
    
    if multipass_instance_exists $MASTER_NODE_NAME; then
      create_master_node $MASTER_NODE_NAME
      deploy_kubernetes_distribution master $MASTER_NODE_NAME
      copy_config_file $MASTER_NODE_NAME
    fi
  done
  
  #Deploy and configure WORKER nodes
  for ((counter=1; counter<=$WORKER_NODE_COUNT; counter++))
  do
    WORKER_NODE_NAME=$WORKER_NODE_PREFIX-$counter
    
    if multipass_instance_exists $WORKER_NODE_NAME; then
      create_worker_node $WORKER_NODE_NAME
      deploy_kubernetes_distribution worker $WORKER_NODE_NAME
    fi
  done
}

function init() {
  deploy_and_configure_nodes
}

init;
