#!/bin/bash
#
# mod-usage: mod fork <network> [anvil args...]
# mod-usage: mod fork <env> [layer] [anvil args...]
# mod-usage: mod fork <url> [anvil args...]
# mod-description: start a local anvil fork of a network
# mod-arg: <network>       network key under .rpc in mod.config.json
# mod-arg: <env> [layer]   environment, plus a layer when its rpc is an object
# mod-arg: <url>           an http(s) or ws(s) rpc url, used as is
# mod-arg: [anvil args]    passed straight to anvil, e.g. --port 8546,
# mod-arg:                 --host 0.0.0.0, --state fork.json, --fork-block-number N
# mod-note: The rpc is resolved the same way as `mod rpc` and handed to anvil as
# mod-note: --fork-url. Everything after it is anvil's own, so any anvil option
# mod-note: works; see `anvil --help`.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help fork
    exit 0
  fi

  if [ $# -lt 1 ]; then
    mod_missing_args fork
  fi

  if ! command -v anvil >/dev/null 2>&1; then
    echo "Error: anvil not found. Install foundry: https://getfoundry.sh" >&2
    exit 1
  fi

  local target="$1" url
  shift
  case "$target" in
    http://*|https://*|ws://*|wss://*)
      url="$target"
      ;;
    *)
      if mod_is_layer "$target" "${1:-}"; then
        url="$("$MOD" rpc "$target" "$1")"
        shift
      else
        url="$("$MOD" rpc "$target")"
      fi
      ;;
  esac

  if [ -z "$url" ]; then
    echo "Error: could not resolve an rpc url for '$target'." >&2
    echo "Run 'mod config check' to list networks and envs." >&2
    exit 1
  fi

  echo "Forking $url" >&2
  exec anvil --fork-url "$url" "$@"
}

main "$@"
