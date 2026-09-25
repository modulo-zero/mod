#!/bin/bash
#
# mod-usage: mod drain <address>
# mod-description: sweep balances into an address
# mod-arg: <address>   address to sweep the funds into
# mod-note: Incomplete: the cast send is commented out, so this currently only
# mod-note: prints balances. See the known gaps in the README.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

ORANGE='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help drain
    exit 0
  fi

  if [ $# -lt 1 ]; then
    mod_missing_args drain
  fi

  SENDER="--sender $(cast wallet address $(mod_account_args $ACCOUNT)) $(mod_account_args $ACCOUNT)"

  rpcs_string=$(mod_config_json | jq -r ".rpc" | jq -r "keys[]")
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
