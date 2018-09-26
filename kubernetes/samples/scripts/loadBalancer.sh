#!/bin/bash

#  This script is to create or delete Ingress controllers.
#  Copyright 2017, 2018, Oracle Corporation and/or affiliates.  All rights reserved.

function createVoyager() {
  echo "Creating Voyager operator on namespace 'voyager'."
  echo

  which onessl
  if [ $? != 0 ]; then
    echo "Install Utility onessl. The pre-consumption is that you have added ~/bin to your PATH env."
    curl -fsSL -o onessl https://github.com/kubepack/onessl/releases/download/0.3.0/onessl-linux-amd64 \
      && chmod +x onessl \
      && mv onessl ~/bin
  else
    echo "Onessl is already installed. "
  fi
  echo

  if [ "$(helm search appscode/voyager | grep voyager |  wc -l)" = 0 ]; then
    echo "Add Appscode Chart Repository"
    helm repo add appscode https://charts.appscode.com/stable/
    helm repo update
  else
    echo "Appscode Chart Repository is already added."
  fi
  echo

  # Install Voyager to K8S 1.9.x - 1.10.x
  if [ "$(helm list | grep voyager-operator |  wc -l)" = 0 ]; then
    echo "Ihstall voyager operator."
    helm install appscode/voyager --name voyager-operator --version 7.4.0 \
      --namespace voyager \
      --set cloudProvider=baremetal \
      --set apiserver.ca="$(onessl get kube-ca)" \
      --set apiserver.enableValidatingWebhook=true
  else
    echo "Voyager operator is already installed."
  fi 
  echo

  echo "Wait until Voyager operator running."
  max=20
  count=0
  while [ $count -lt $max ]; do
    kubectl -n voyager get pod
    if [ "$(kubectl -n voyager get pod | grep voyager | awk '{ print $2 }')" = 1/1 ]; then
      echo "Voyager operator is running now."
      exit 0;
    fi
    count=`expr $count + 1`
    sleep 5
  done
  echo "Error: Voyager operator failed to start."

}

function createTraefik() {
  echo "Creating Traefik operator on namespace 'traefik'." 
  echo

  if [ "$(helm list | grep traefik-operator |  wc -l)" = 0 ]; then
    echo "Install Traefik Operator."
    helm install --name traefik-operator --namespace traefik --values traefik-values.yaml stable/traefik
  else
    echo "Traefik Operator is already installed."
  fi
  echo

  echo "Wait until Traefik operator running."
  max=20
  count=0
  while test $count -lt $max; do
    kubectl -n traefik get pod
    if test "$(kubectl -n traefik get pod | grep traefik | awk '{ print $2 }')" = 1/1; then
      echo "Traefik operator is running now."
      exit 0;
    fi
    count=`expr $count + 1`
    sleep 5
  done
  echo "Error: Traefik operator failed to start."
}

function deleteVoyager() {
  if [ "$(helm list | grep voyager-operator |  wc -l)" = 1 ]; then
    echo "Delete Voyager Operator. "
    helm delete --purge voyager-operator
    kubectl delete ns voyager
  else
    echo "Voyager operator has already been deleted." 
  fi
  echo

  if [ "$(helm search appscode/voyager | grep voyager |  wc -l)" != 0 ]; then
    echo "Remove Appscode Chart Repository."
    helm repo remove appscode
  fi
  echo

  # No harm to keep onessl, specially considering installing it takes time
  # Remove onessl.
  #if [ -e ~/bin/onessl ]; then
  #  rm ~/bin/onessl
  #fi
 
}

function deleteTraefik() {
  if [ "$(helm list | grep traefik-operator |  wc -l)" = 1 ]; then
    echo "Delete Traefik operator." 
    helm delete --purge traefik-operator
    kubectl delete ns traefik
  else
    echo "Traefik operator has already been deleted." 
  fi
}

function usage() {
  echo "usage: $0 create|delete traefik|voyager"
  exit 1
}

function main() {
  if [ "$#" != 2 ]; then
    usage
  fi
  if [ "$1" != create ] && [ "$1" != delete ]; then
    usage
  fi
  if [ "$2" != traefik ] && [ "$2" != voyager ]; then
    usage
  fi

  if [ "$1" = create ]; then
    if [ "$2" = traefik ]; then
      createTraefik
    else
      createVoyager
    fi
  else
    if [ "$2" = traefik ]; then
      deleteTraefik
    else
      deleteVoyager
    fi
  fi
}

main "$@"