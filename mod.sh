#!/bin/bash

usage() {
  cat <<'EOF'
mod-cli - tools for working on mod projects

Usage:
  mod <command> [args...]

Commands:
  address       <network> <contract-name>                     print a deployed contract address
  balance       <env> [l1|l2] <address>                       show the ether balance of an address
  balance-full  <address>                                     show that balance on every configured network
  call          <env> [l1|l2] <address> <selector> [args...]  make a read-only contract call
  drain         <address>                                     sweep balances into an address
  e2e           <env> <layers> <contract> <selector> [args]   run an end-to-end script sequence
  pk            <account>                                     print the private key for a keystore account
  rpc           <network> | <env> <l1|l2>                     resolve the rpc url for a network
  script        <env> [l1|l2] <contract> <selector> [args...] run a forge script
  send          <env> [l1|l2] <address> <selector> [args...]  send a transaction
  tenderly      <env> <l1|l2>                                 create a tenderly fork and print its id
  trace         <tx-hash>                                     visualize a transaction trace
  verify        <verifier> <chain-id> <address> <contract>    verify a deployed contract
  wallet        <subcommand> [args...]                        manage keystore accounts
  help                                                        show this message

Aliases:
  a=address  b=balance  c=call  e=e2e  r=rpc  s=script  t=trace  ve=verify  wa=wallet

Environment:
  ACCOUNT    keystore account used to sign for script and send
  FORK=true  route balance, call, script and send through a fresh tenderly fork

Commands that take <env> read it from the mod.config.json of the project you are
currently in. See the README for the full list of subcommands and known gaps.
EOF
}

main() {
  # The directory of the script
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  if [[ $MOD_INIT -ne "1" ]]; then
    # Check if the env has been loaded properly
    if [ ! -f "${DIR}/.env" ]; then
      echo "Error: no .env found at ${DIR}/.env"
      echo "Create one from the template with: cp ${DIR}/.env.config ${DIR}/.env"
      exit 1
    fi
    source "${DIR}/.env"

    export MOD_INIT=1

    export MOD="${DIR}/mod.sh"
    mod() {
      $MOD $@
    }
    export -f mod
  fi

  # Show usage when no command is given, or when help is asked for by name.
  # This runs before get_config so that it works outside of a mod project.
  case "${1:-}" in
    "" | help | -h | --help)
      usage
      [ "$#" -lt 1 ] && exit 1
      exit 0
      ;;
  esac

  get_config

  cd $PROJECT_DIR

  call $@
}

call() {
  # Apply aliases for convenience
  CMD="${1}"
  case $CMD in
    b) CMD=balance ;;
    t) CMD=trace ;;
    ve) CMD=verify ;;
    wa) CMD=wallet ;;
    s) CMD=script ;;
    a) CMD=address ;;
    e) CMD=e2e ;;
    c) CMD=call ;;
    r) CMD=rpc ;;
  esac

  if [[ $CMD == "balance" || $CMD == "script" || $CMD == "call" || $CMD == "send" ]]; then
    if [[ $FORK == "true" ]]; then
      if [[ $3 == "l1" || $3 == "l2" ]]; then
        export DEPLOYMENT_ENVIRONMENT=$2
        export DEPLOYMENT_LAYER=$3
        export FORK_ID=$(mod tenderly $2 $3)
        export RPC=https://rpc.tenderly.co/fork/$FORK_ID
        shift 2
      else
        export DEPLOYMENT_ENVIRONMENT=$2
        export FORK_ID=$(mod tenderly $2)
        export RPC=https://rpc.tenderly.co/fork/$FORK_ID
        shift 1
      fi
      echo
      echo https://dashboard.tenderly.co/$TENDERLY_ORG/$TENDERLY_PROJECT/fork/$FORK_ID
      echo
    else
      export VERIFY=$(cat ${PROJECT_DIR}/mod.config.json | jq -r ".envs.\"${2}\".verify")
      if [[ $3 == "l1" || $3 == "l2" ]]; then
        export DEPLOYMENT_ENVIRONMENT=$2
        export DEPLOYMENT_LAYER=$3
        export RPC=$(mod rpc $2 $3)
        shift 2
      else
        export DEPLOYMENT_ENVIRONMENT=$2
        export RPC=$(mod rpc $2)
        shift 1
      fi
    fi
  fi

  # Execute the command
  shift
  if [ -f "${DIR}/bin/${CMD}/index.js" ]; then
    node "${DIR}/bin/${CMD}/index.js" $@
  elif [ -f "${DIR}/bin/${CMD}/index.sh" ]; then
    "${DIR}/bin/${CMD}/index.sh" "$@"
  else
    echo "Error: unknown command '${CMD}'"
    echo "Run 'mod help' to see the available commands."
    exit 2
  fi
}

get_config() {
  dir=$(pwd -P)
  while [ -n "$dir" -a ! -f "$dir/mod.config.json" ]; do
      dir=${dir%/*}
  done
  if [[ $dir != "" ]]; then
    export PROJECT_DIR=$dir
  fi
}

main $@
