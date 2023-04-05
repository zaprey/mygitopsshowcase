#!/bin/bash

####################
# Settings
####################

# OS and arch settings
HOSTOS=$(uname -s | tr '[:upper:]' '[:lower:]')
HOSTARCH=$(uname -m)
SAFEHOSTARCH=${HOSTARCH}
if [[ ${HOSTOS} == darwin ]]; then
  SAFEHOSTARCH=amd64
fi
if [[ ${HOSTARCH} == x86_64 ]]; then
  SAFEHOSTARCH=amd64
fi
HOST_PLATFORM=${HOSTOS}_${HOSTARCH}
SAFEHOSTPLATFORM=${HOSTOS}-${SAFEHOSTARCH}

# Directory settings
ROOT_DIR=$(cd -P $(dirname $0) >/dev/null 2>&1 && pwd)
DEPLOY_LOCAL_WORKDIR=${ROOT_DIR}/.work/local/localdev
TOOLS_HOST_DIR=${ROOT_DIR}/.cache/tools/${HOST_PLATFORM}

mkdir -p ${DEPLOY_LOCAL_WORKDIR}
mkdir -p ${TOOLS_HOST_DIR}

# Custom settings
. ${ROOT_DIR}/config.sh

####################
# Utility functions
####################

CYAN="\033[0;36m"
NORMAL="\033[0m"
RED="\033[0;31m"

function info {
  echo -e "${CYAN}INFO  ${NORMAL}$@" >&2
}

function error {
  echo -e "${RED}ERROR ${NORMAL}$@" >&2
}

function wait-deployment {
  local object=$1
  local ns=$2
  echo -n "Waiting for deployment $object in $ns namespace ready "
  retries=600
  until [[ $retries == 0 ]]; do
    echo -n "."
    local result=$(${KUBECTL} get deploy $object -n $ns -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    if [[ $result == 1 ]]; then
      echo " Done"
      break
    fi
    sleep 1
    retries=$((retries - 1))
  done
  [[ $retries == 0 ]] && echo
}

####################
# Preflight check
####################

function preflight-check {
  if ! command -v docker >/dev/null 2>&1; then
    error "docker not installed, exit."
    exit 1
  fi
}

####################
# Install kind
####################

KIND=${TOOLS_HOST_DIR}/kind-${KIND_VERSION}

function install-kind {
  info "Installing kind ${KIND_VERSION} ..."

  if [[ ! -f ${KIND} ]]; then
    curl -fsSLo ${KIND} https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-${SAFEHOSTPLATFORM} || exit -1
    chmod +x ${KIND}
  else
    echo "kind ${KIND_VERSION} detected."
  fi

  info "Installing kind ${KIND_VERSION} ... OK"
}

####################
# Install kubectl
####################

KUBECTL=${TOOLS_HOST_DIR}/kubectl-${KUBECTL_VERSION}

function install-kubectl {
  info "Installing kubectl ${KUBECTL_VERSION} ..."

  if [[ ! -f ${KUBECTL} ]]; then
    curl -fsSLo ${KUBECTL} https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/${HOSTOS}/${SAFEHOSTARCH}/kubectl || exit -1
    chmod +x ${KUBECTL}
  else
    echo "kubectl ${KUBECTL_VERSION} detected."
  fi

  info "Installing kubectl ${KUBECTL_VERSION} ... OK"
}

####################
# Launch kind
####################

# The cluster information
KIND_CLUSTER_NAME=mygitopscluster

function kind-up {
  info "kind up ..."

  KIND_CONFIG_FILE=${ROOT_DIR}/kind-cluster.yaml
  ${KIND} get kubeconfig --name ${KIND_CLUSTER_NAME} >/dev/null 2>&1 || ${KIND} create cluster --name=${KIND_CLUSTER_NAME} --config="${KIND_CONFIG_FILE}"

  info "kind up ... OK"
}

function kind-down {
  info "kind down ..."

  ${KIND} delete cluster --name=${KIND_CLUSTER_NAME}

  info "kind down ... OK"
}

####################
# Install Argo CD
####################

ARGOCD_CLI=${TOOLS_HOST_DIR}/argocd-${ARGOCD_CLI_VERSION}

function install-argocd {
  info "Installing Argo CD ${ARGOCD_VERSION} ..."

  ${KUBECTL} get ns -o name | grep -q argocd || ${KUBECTL} create namespace argocd
  ${KUBECTL} apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

  wait-deployment argocd-server argocd

  ${KUBECTL} patch service/argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"name":"https", "nodePort": 30443, "port": 443}]}}'

  info "Installing Argo CD ${ARGOCD_VERSION} ... OK"
}

function install-argocd-cli {
  info "Installing Argo CD CLI ${ARGOCD_CLI_VERSION} ..."

  if [[ ! -f ${ARGOCD_CLI} ]]; then
    curl -fsSLo ${ARGOCD_CLI} https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_CLI_VERSION}/argocd-${HOSTOS}-${SAFEHOSTARCH} || exit -1
    chmod +x ${ARGOCD_CLI}
  else
    echo "Argo CD CLI ${ARGOCD_CLI_VERSION} detected."
  fi

  info "Installing Argo CD CLI ${ARGOCD_CLI_VERSION} ... OK"
}


####################
# Install KubeSeal CLI
####################

KUBESEAL_CLI=${TOOLS_HOST_DIR}/kubeseal-${KUBESEAL_CLI_VERSION}

function install-kubeseal-cli {
  info "Installing KubeSeal CLI ${KUBESEAL_CLI_VERSION} ..."

  if [[ ! -f ${KUBESEAL_CLI} ]]; then
    curl -fsSLo ${KUBESEAL_CLI} https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_CLI_VERSION}/kubeseal-${HOSTOS}-${SAFEHOSTARCH} || exit -1
    chmod +x ${KUBESEAL_CLI}
  else
    echo "KubeSeal CLI ${KUBESEAL_CLI_VERSION} detected. "
  fi

  info "Installing KubeSeal CLI ${KUBESEAL_CLI_VERSION} ... OK"
}

####################
# Print summary after install
####################

function print-summary {
  cat << EOF
👏 Congratulations! The GitOps demo environment is available!
It launched a kind cluster, installed following tools and applitions:
- kind ${KIND_VERSION}
- kubectl ${KUBECTL_VERSION}
- argocd ${ARGOCD_VERSION}
- argocd cli ${ARGOCD_CLI_VERSION}
- kubeseal cli ${KUBESEAL_CLI_VERSION}
$(print-console)
For tools you want to run anywhere, create links in a directory defined in your PATH, e.g:
ln -s -f ${KUBECTL} /usr/local/bin/kubectl
ln -s -f ${KIND} /usr/local/bin/kind
ln -s -f ${ARGOCD_CLI} /usr/local/bin/argocd
ln -s -f ${KUBESEAL_CLI} /usr/local/bin/kubeseal
EOF
}

function print-console {
  ARGOCD_PASSWORD="$(${KUBECTL} -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"

  cat << EOF
To access Argo CD UI, open https://$(hostname):9443 in browser.
- username: admin
- password: ${ARGOCD_PASSWORD}
EOF
}

####################
# Generate cluster info
####################

function gen-cluster-config {
  info "Generating cluster information ..."

  local ns=${1:-dev}

  CLUSTER_CONFIG_PATH=$(cd -P ${ROOT_DIR}/../env/overlays/${ns}/env >/dev/null 2>&1 && pwd)

  KUBESVC_IP=$(${KUBECTL} get service kubernetes -o jsonpath='{.spec.clusterIP}')
  CLUSTER_CONFIG=$(${KIND} get kubeconfig --name ${KIND_CLUSTER_NAME} | sed -e "s|server:\s*.*$|server: https://${KUBESVC_IP}|g")
  ${KUBECTL} create secret generic cluster-config --from-literal=kubeconfig="${CLUSTER_CONFIG}" --dry-run -o yaml > ${CLUSTER_CONFIG_PATH}/cluster-config.yaml
  ${KUBESEAL_CLI} -n ${ns} --controller-namespace argocd < ${CLUSTER_CONFIG_PATH}/cluster-config.yaml > ${CLUSTER_CONFIG_PATH}/cluster-config.json.tmp
  if [[ $? == 0 ]]; then
    mv ${CLUSTER_CONFIG_PATH}/cluster-config.json{.tmp,}
    echo "The file ${CLUSTER_CONFIG_PATH}/cluster-config.json is updated, please check in to git."
  else
    rm ${CLUSTER_CONFIG_PATH}/cluster-config.json.tmp
    exit 1
  fi
  # rm -f ${CLUSTER_CONFIG_PATH}/cluster-config.yaml

  info "Generating cluster information ... OK"
}

####################
# Patch image pull secret
####################

function patch-pull-secret {
  namespace='argocd'
  positional=('deploy/argocd-redis')

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace="$2"; shift; shift ;;
    *)
      positional+=("$1"); shift ;;
    esac
  done

  echo -n "Enter docker username: "
  read DOCKER_USERNAME

  echo -n "Enter docker password: "
  read -s DOCKER_PASSWORD
  echo

  ${KUBECTL} create secret docker-registry docker-pull --docker-server=docker.io --docker-username=${DOCKER_USERNAME} --docker-password=${DOCKER_PASSWORD} -n $namespace
  ${KUBECTL} patch ${positional[@]} -n $namespace -p '{"spec": {"template": {"spec": {"imagePullSecrets":[{"name":"docker-pull"}]}}}}'
}

####################
# Print help
####################

function print-help {
  cat << EOF
Usage: $0 up
       $0 down
       $0 cluster-config <namespace>
       $0 patch-pull-secret <resource> -n <namespace>
       $0 console
Examples:
  # Bring up the demo environment on your machine
  $0 up
  # Take down the demo environment on your machine
  $0 down
  # Generate and update the cluster-config secret encrypted by kubeseal for the demo environment
  # <namespace> default to dev if omitted
  $0 cluster-config
  # Patch image pull secret for specific deployment from docker hub
  # <resource> default to deployment/argocd-redis if omitted
  # <namespace> default to argocd if omitted
  $0 patch-pull-secret
  # Print Argo CD UI Console access information
  $0 console
EOF
}

####################
# Main entrance
####################

case $1 in
  "down")
    install-kind
    kind-down
    ;;
  "up")
    install-kind
    install-kubectl
    kind-up
    install-argocd
    install-argocd-cli
    install-kubeseal-cli
    print-summary
    ;;
  "cluster-config")
    install-kubeseal-cli
    gen-cluster-config ${@:2}    
    ;;
  "patch-pull-secret")
    patch-pull-secret ${@:2}
    ;;
  "console")
    print-console
    ;;
  *)    
    print-help
    ;;
esac
