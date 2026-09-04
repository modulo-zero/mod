#!/bin/bash

ORANGE='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function main() {
  if [ $# -lt 1 ]; then
    echo "Usage: mod drain <address>"
    exit 1
  fi

  SENDER="--sender $(cast wallet address --account $ACCOUNT) --account $ACCOUNT"

  rpcs_string=$(cat mod.config.json | jq -r ".rpc" | jq -r "keys[]")
  read -a rpcs <<< $rpcs_string

  for rpc in ${rpcs[@]}; do
    if [[ "$rpc" != "devnet-l1" && "$rpc" != "devnet-l2" ]]; then
      RPC=$(mod rpc $rpc)
      balance=$(cast balance --rpc-url $RPC $1 --ether)
      echo $balance
      if [[ balance > 0.01 ]]; then
        echo $RPC
        echo $($balance -min 0.01)
        # cast send --rpc-url $RPC $address --value $($balance - 0.01)
      fi
    fi
  done
}

main $@
