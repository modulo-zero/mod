#!/bin/bash

function checkStatus {
  if [ ! $? -eq 0 ]; then
    exit 1
  fi
}

function main() {
  if [ $# -lt 2 ]; then
    echo "Usage: mod script <env> [l1|l2] <script-contract> <function-selector> [args...]"
    exit 1
  fi

  SCRIPT_CONTRACT=$1
  FUNCTION_NAME=$2
  ARGS=${@:3}

  if [ -z $ACCOUNT ]; then
    SENDER=""
  else
    CALLER=$(cast wallet address --account $ACCOUNT)
    SENDER="--sender $CALLER --account $ACCOUNT"
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
