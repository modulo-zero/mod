#!/bin/bash

function main() {
  if [[ -z $1 ]] || [[ -z $2 ]]; then
      echo "Usage: mod tenderly <env> <l1|l2>"
      exit 1
  fi

  RPC=$(mod rpc $1 $2)
  BLOCK_NUMBER=$(cast block-number --rpc-url $RPC)
  CHAIN_ID=$(cast chain-id --rpc-url $RPC)
  BODY="{\"network_id\": \"$CHAIN_ID\", \"block_number\": $BLOCK_NUMBER, \"chain_config\": {\"chain_id\": $CHAIN_ID}}"
  OUTPUT=$(curl https://api.tenderly.co/api/v1/account/$TENDERLY_ORG/project/$TENDERLY_PROJECT/fork \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-Access-Key: ${TENDERLY_API_KEY}" \
    --data "${BODY}")
  FORK_ID=$(echo $OUTPUT | jq ".simulation_fork.id" | sed 's:^.\(.*\).$:\1:')
  echo $FORK_ID
}

main $@
