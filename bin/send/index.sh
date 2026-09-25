#!/bin/bash
#
# mod-usage: mod send <env> [layer] <address> <function-selector> [args...]
# mod-description: send a transaction
# mod-arg: <env>                 environment named in the project's mod.config.json
# mod-arg: [layer]               layer, for environments whose rpc is an object
# mod-arg: <address>             contract to send to
# mod-arg: <function-selector>   signature, e.g. 'transfer(address,uint256)'
# mod-arg: [args...]             arguments to the function
# mod-note: Signs with the keystore account named in ACCOUNT, if that is set.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help send
    exit 0
  fi

  if [ $# -lt 2 ]; then
    mod_missing_args send
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
    SENDER="$(mod_account_args $ACCOUNT)"
  fi

  cast send --rpc-url $RPC $SENDER $ADDRESS "$SELECTOR" $PARAMS
}

main $@
