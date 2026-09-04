#!/bin/bash

function main() {
  if [[ -z $1 ]] || [[ -z $2 ]] || [[ -z $3 ]] || [[ -z $4 ]]; then
      echo "Usage: mod verify <verifier> <chain-id> <address> <contract> [forge-args...]"
      echo "Verifiers: etherscan, blastscan, tenderly, tenderly-fork"
      exit 1
  fi

  if [ $1 = "etherscan" ]; then
    etherscan ${@:2}
  elif [ $1 = "blastscan" ]; then
    blastscan ${@:2}
  elif [ $1 = "tenderly" ]; then
    tenderly ${@:2}
  elif [ $1 = "tenderly-fork" ]; then
    tenderly_fork ${@:2}
  else
    echo "Error: verifier '${1}' is not supported"
    echo "Verifiers: etherscan, blastscan, tenderly, tenderly-fork"
  fi
}

function etherscan() {
  echo "WARNING: this will publicly verify the contract"
  read -p "Proceed: " response
  if [ $response = "y" ] || [ $response = "yes" ]; then
    forge verify-contract $2 \
      $3 \
      --verifier etherscan \
      --chain-id $1 \
      --watch \
      --etherscan-api-key $ETHERSCAN_API_KEY \
      ${@:4}
  fi
}

function tenderly() {
  export ETHERSCAN_API_KEY=""
  forge verify-contract $2 \
    $3 \
    --verifier-url "https://api.tenderly.co/api/v1/account/$TENDERLY_ORG/project/$TENDERLY_PROJECT/etherscan/verify/network/${1}" \
    --chain-id $1 \
    --watch \
    --etherscan-api-key $TENDERLY_API_KEY \
    ${@:4}
}

function tenderly_fork() {
  export ETHERSCAN_API_KEY=""
  forge verify-contract $2 \
    $3 \
    --verifier-url "https://api.tenderly.co/api/v1/account/$TENDERLY_ORG/project/$TENDERLY_PROJECT/etherscan/verify/fork/${1}" \
    --watch \
    --etherscan-api-key $TENDERLY_API_KEY \
    ${@:4}
}

function blastscan() {
  echo "WARNING: this will publicly verify the contract"
  read -p "Proceed: " response
  if [ $response = "y" ] || [ $response = "yes" ]; then
    if [ $1 == "81457" ]; then
      URL="https://api.blastscan.io/api?apikey=$BLASTSCAN_API_KEY"
    else
      URL="https://api-sepolia.blastscan.io/api?apikey=$BLASTSCAN_API_KEY"
    fi
    export ETHERSCAN_API_KEY=$BLASTSCAN_API_KEY
    forge verify-contract $2 \
      $3 \
      --verifier-url $URL \
      --etherscan-api-key $BLASTSCAN_API_KEY \
      --watch \
      ${@:4}
  fi
}

main $@
