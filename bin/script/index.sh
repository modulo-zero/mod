#!/bin/bash
#
# mod-usage: mod script <env> [layer] <script-contract> <function-selector> [args...]
# mod-description: run a forge script
# mod-arg: <env>                 environment named in the project's mod.config.json
# mod-arg: [layer]               layer, for environments whose rpc is an object
# mod-arg: <script-contract>     forge script contract to run
# mod-arg: <function-selector>   signature to invoke, e.g. 'run()'
# mod-arg: [args...]             extra arguments passed through to forge script
# mod-note: Signs with the keystore account named in ACCOUNT, if that is set.
# mod-note: Prompts for confirmation when the environment has verify set to true.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function checkStatus {
  if [ ! $? -eq 0 ]; then
    exit 1
  fi
}

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help script
    exit 0
  fi

  if [ $# -lt 2 ]; then
    mod_missing_args script
  fi

  SCRIPT_CONTRACT=$1
  FUNCTION_NAME=$2
  ARGS=${@:3}

  if [ -z $ACCOUNT ]; then
    SENDER=""
  else
    CALLER=$(cast wallet address $(mod_account_args $ACCOUNT))
    SENDER="--sender $CALLER $(mod_account_args $ACCOUNT)"
  fi

  COMMAND="forge script --rpc-url $RPC $SENDER $SCRIPT_CONTRACT --sig $FUNCTION_NAME $ARGS"
  echo $COMMAND

  CHAIN_ID=$(cast chain-id --rpc-url $RPC)
  if [[ $VERIFY == 'true' ]]; then
    echo "WARNING: this script will run against"
    echo "chainId: ${CHAIN_ID}"
    echo "caller: ${CALLER}"
    read -p "Proceed: " response
    if [ $response = "y" ] || [ $response = "yes" ]; then
      echo "Executing"
    else
      echo "Script aborted"
      exit 1
    fi
  fi

  STRICT_DEPLOYMENT=false $COMMAND

  checkStatus

  export SIG=$(echo $FUNCTION_NAME | cut -d "(" -f 1)
  if [ -f "./broadcast/${SCRIPT_CONTRACT}.s.sol/${CHAIN_ID}/${SIG}-latest.json" ]; then
    echo "Syncing transactions"
    forge script $SENDER --rpc-url $RPC $SCRIPT_CONTRACT --sig 'sync()'
  fi

  if [[ $FORK == "true" ]]; then
    echo "Fork url: https://dashboard.tenderly.co/$TENDERLY_ORG/$TENDERLY_PROJECT/fork/$FORK_ID"
  fi
}

main $@
