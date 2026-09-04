#!/bin/bash
#
# mod-usage: mod balance <env> [l1|l2] <address>
# mod-description: show the ether balance of an address
# mod-arg: <env>       environment named in the project's mod.config.json
# mod-arg: [l1|l2]     layer, for environments that define both
# mod-arg: <address>   address to look up

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

ORANGE='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help balance
    exit 0
  fi

  if [ $# -lt 1 ]; then
    mod_missing_args balance
  fi

  echo -e "$(cast balance --rpc-url $RPC $1 --ether) ${ORANGE}ETH ${NC}"
}

main $@
