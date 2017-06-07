#!/usr/bin/env bash

set -eu
export LC_ALL=C

export NODE_IP=${1:-${NODE_IP}}

ROOT=$(dirname "${BASH_SOURCE}")
if [ -f "${ROOT}/default-env.sh" ]; then
    source ${ROOT}/default-env.sh
fi

source ${ROOT}/configure-kubeconfig.sh
source ${ROOT}/configure-scheduler.sh
