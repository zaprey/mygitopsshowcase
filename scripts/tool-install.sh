#! /bin/bash

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

function info {
  echo -e "${CYAN}INFO  ${NORMAL}$@" >&2
}

function error {
  echo -e "${RED}ERROR ${NORMAL}$@" >&2
}

# Custom settings
. ${ROOT_DIR}/config.sh

####################
# Utility functions
####################

CYAN="\033[0;36m"
NORMAL="\033[0m"
RED="\033[0;31m"


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
# Install KubeSeal CLI
####################

KUBESEAL_CLI=${TOOLS_HOST_DIR}/kubeseal-${KUBESEAL_CLI_VERSION}

function install-kubeseal-cli {
  info "Installing KubeSeal CLI ${KUBESEAL_CLI_VERSION} ..."

  if [[ ! -f ${KUBESEAL_CLI} ]]; then
    curl -fsSLo ${KUBESEAL_CLI} https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_CLI_VERSION:0}/kubeseal-${KUBESEAL_CLI_VERSION:1}-${HOSTOS}-${SAFEHOSTARCH}.tar.gz || exit -1
    chmod +x ${KUBESEAL_CLI}
  else
    echo "KubeSeal CLI ${KUBESEAL_CLI_VERSION} detected. "
  fi

  info "Installing KubeSeal CLI ${KUBESEAL_CLI_VERSION} ... OK"
}


####################
# Install ARGOCD CLI
####################


ARGOCD_CLI=${TOOLS_HOST_DIR}/argocd-${ARGOCD_CLI_VERSION}


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





function print-summary {
    cat <<  EOF
For tools you want to run anywhere, create links in a directory defined in your PATH, e.g:
sudo ln -s -f ${KUBECTL} /usr/local/bin/kubectl
sudo ln -s -f ${KIND} /usr/local/bin/kind
sudo ln -s -f ${ARGOCD_CLI} /usr/local/bin/argocd
sudo ln -s -f ${KUBESEAL_CLI} /usr/local/bin/kubeseal
EOF
}


install-kind
install-kubectl
install-kubeseal-cli
install-argocd-cli

print-summary