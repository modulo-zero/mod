#!/bin/bash
#
# mod-usage: mod balance-full <address>
# mod-description: show the balance of an address on every configured network
# mod-arg: <address>   address to look up
# mod-note: Reads the rpc keys of the current project's mod.config.json and
# mod-note: skips the devnet-l1 and devnet-l2 entries.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

ORANGE='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help balance-full
    exit 0
  fi

  if [ $# -lt 1 ]; then
    mod_missing_args balance-full
  fi
  rpcs_string=$(cat mod.config.json | jq -r ".rpc" | jq -r "keys[]")
  read -a rpcs <<< $rpcs_string

  for rpc in ${rpcs[@]}; do
    if [[ "$rpc" != "devnet-l1" && "$rpc" != "devnet-l2" ]]; then
      echo $rpc $(mod balance $rpc $1)
    fi
  done
}

main $@
