#!/bin/bash

function main() {
  if [ $# -lt 2 ]; then
    echo "Usage: mod send <env> [l1|l2] <address> <function-selector> [args...]"
    exit 1
  fi

  ADDRESS=$1
  if [[ $3 == "returns" ]]; then
    SELECTOR="$2 $3 $4"
    PARAMS=${@:5}
  else
    SELECTOR=$2
    PARAMS=${@:3}
  fi

  if [ -z $ACCOUNT ]; then
    SENDER=""
  else
    SENDER="--account $ACCOUNT"
  fi

  cast send --rpc-url $RPC $SENDER $ADDRESS "$SELECTOR" $PARAMS
}

main $@
