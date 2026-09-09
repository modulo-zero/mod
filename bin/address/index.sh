#!/bin/bash
#
# mod-usage: mod address <network> <contract-name>
# mod-description: print a deployed contract address
# mod-arg: <network>        network directory under deployments/
# mod-arg: <contract-name>  deployment file name, without the .json suffix

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help address
    exit 0
  fi

  if [ $# -lt 2 ]; then
    mod_missing_args address
  fi

  ADDRESS=$(cat "deployments/$1/$2.json" | jq '.address' | sed 's:^.\(.*\).$:\1:')
  echo $ADDRESS
}

main $@
