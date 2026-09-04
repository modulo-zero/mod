#!/bin/bash

function main() {
  if [ $# -lt 2 ]; then
    echo "Usage: mod call <env> [l1|l2] <address> <function-selector> [args...]"
    exit 1
  fi

  ADDRESS=$1
  if [[ $3 == "returns" ]]; then
    SELECTOR="$2 $3 $4"
    PARAMS=${@:5}
  else
    SELECTOR=$1
    PARAMS=${@:2}
  fi

  cast call --rpc-url $RPC $ADDRESS "$SELECTOR" $PARAMS --keystore ~/.foundry/keystores
}

main $@
