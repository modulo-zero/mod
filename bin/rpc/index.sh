#!/bin/bash
#
# mod-usage: mod rpc <network>
# mod-usage: mod rpc <env> [layer]
# mod-description: resolve the rpc url for a network
# mod-arg: <network>   network key under .rpc in mod.config.json
# mod-arg: <env>       environment named under .envs in mod.config.json
# mod-arg: [layer]     layer to resolve, for environments whose rpc is an object
# mod-arg:             such as {l1, l2} or {ethereum, solana}; all are printed as
# mod-arg:             json if omitted

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help rpc
    exit 0
  fi

  if [ $# -lt 1 ]; then
    mod_missing_args rpc
  fi

  local config value
  config="$(mod_config_json)"
  value="$(jq -c --arg env "$1" '.envs[$env].rpc // empty' <<< "$config")"

  case "$(jq -r 'type' <<< "${value:-null}")" in
    string)
      rpc_from_network "$(jq -r . <<< "$value")"
      ;;
    object)
      if [ -n "${2:-}" ]; then
        if ! jq -e --arg l "$2" 'has($l)' <<< "$value" >/dev/null; then
          echo "Error: environment '$1' has no layer '$2'. Layers: $(jq -r 'keys | join(", ")' <<< "$value")" >&2
          exit 1
        fi
        rpc_from_network "$(jq -r --arg l "$2" '.[$l]' <<< "$value")"
      else
        # every layer resolved to its url, as {layer: url}
        jq --argjson rpc "$(jq '.rpc // {}' <<< "$config")" \
           'with_entries(.value = ($rpc[.value].url // .value))' <<< "$value"
      fi
      ;;
    *)
      # not an environment: treat the argument as a network name
      rpc_from_network "$1"
      ;;
  esac
}

function rpc_from_network() {
  mod_config_json | jq -r --arg n "$1" '.rpc[$n].url // empty'
}

main "$@"
