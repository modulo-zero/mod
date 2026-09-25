#!/bin/bash
#
# mod-usage: mod trace <env> [layer] <tx-hash> [cast run args...]
# mod-usage: mod trace <network> <tx-hash> [cast run args...]
# mod-description: print the decoded call trace of a transaction
# mod-arg: <env> [layer]   environment, plus a layer when its rpc is an object
# mod-arg: <network>       or a network key under .rpc in mod.config.json
# mod-arg: <tx-hash>       hash of the transaction to trace
# mod-arg: [args]          passed to cast run, e.g. --debug for the interactive debugger
# mod-note: Wraps `cast run`, which replays the transaction on the rpc and prints
# mod-note: the call tree with contract and function names where it can decode
# mod-note: them. Run it from the forge project the contracts were built in so
# mod-note: local artifacts are used for labels.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help trace
    exit 0
  fi

  if [ $# -lt 2 ]; then
    mod_missing_args trace
  fi

  local target="$1" url
  shift
  if mod_is_layer "$target" "${1:-}"; then
    url="$("$MOD" rpc "$target" "$1")"
    shift
  else
    url="$("$MOD" rpc "$target")"
  fi
  if [ -z "$url" ]; then
    echo "Error: could not resolve an rpc url for '$target'." >&2
    exit 1
  fi
  if [ $# -lt 1 ]; then
    mod_missing_args trace
  fi

  local tx="$1"
  shift
  cast run "$tx" --rpc-url "$url" "$@"
}

main "$@"
