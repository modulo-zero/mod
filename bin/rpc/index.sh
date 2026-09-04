#!/bin/bash

function main() {
  if [ $# -lt 1 ]; then
    echo "Usage: mod rpc <network>"
    echo "   or: mod rpc <env> <l1|l2>"
    exit 1
  fi

  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  VALUE=$(cat ${PROJECT_DIR}/mod.config.json | jq -r ".envs.\"${1}\".rpc")
  if ! jq -e . >/dev/null 2>&1 <<<$(echo $VALUE); then
    if [[ -z $VALUE || $VALUE == "null" ]]; then
      NETWORK=$1
    else
      NETWORK=$VALUE
    fi

    echo $(rpc_from_network $NETWORK)
  else
    L1=$(rpc_from_network $(echo $VALUE | jq -r ".l1"))
    L2=$(rpc_from_network $(echo $VALUE | jq -r ".l2"))
    RPCS=$(jq -n "{ l1: \"$L1\", l2: \"$L2\" }")
    if [[ $2 == "l1" || $2 == "l2" ]]; then
      echo $RPCS | jq -r ".$2"
    else
      echo $RPCS | jq
    fi
  fi
}

function rpc_from_network() {
  echo $(cat ${PROJECT_DIR}/mod.config.json | jq -r ".rpc.\"${1}\".url")
}

main $@
