#!/bin/bash

ORANGE='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function main() {
  if [ $# -lt 1 ]; then
    echo "Usage: mod balance <env> [l1|l2] <address>"
    exit 1
  fi

  echo -e "$(cast balance --rpc-url $RPC $1 --ether) ${ORANGE}ETH ${NC}"
}

main $@
