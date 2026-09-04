#!/bin/bash
#
# mod-usage: mod tenderly <env> <l1|l2>
# mod-description: create a tenderly fork and print its id
# mod-arg: <env>      environment named in the project's mod.config.json
# mod-arg: <l1|l2>    layer to fork
# mod-note: Needs TENDERLY_ORG, TENDERLY_PROJECT and TENDERLY_API_KEY in .env.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help tenderly
    exit 0
  fi

  if [[ -z $1 ]] || [[ -z $2 ]]; then
      mod_missing_args tenderly
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
