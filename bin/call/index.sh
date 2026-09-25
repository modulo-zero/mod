#!/bin/bash
#
# mod-usage: mod call <env> [layer] <address> <function-selector> [args...]
# mod-description: make a read-only contract call
# mod-arg: <env>                 environment named in the project's mod.config.json
# mod-arg: [layer]               layer, for environments whose rpc is an object
# mod-arg: <address>             contract to call
# mod-arg: <function-selector>   signature, e.g. 'balanceOf(address)'
# mod-arg: [args...]             arguments to the function

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help call
    exit 0
  fi

  if [ $# -lt 2 ]; then
    mod_missing_args call
  fi

  ADDRESS=$1
  if [[ $3 == "returns" ]]; then
    SELECTOR="$2 $3 $4"
    PARAMS=${@:5}
  else
    SELECTOR=$2
    PARAMS=${@:3}
  fi

  cast call --rpc-url $RPC $ADDRESS "$SELECTOR" $PARAMS
}

main $@
