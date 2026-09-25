#!/bin/bash
#
# mod-usage: mod fork <env> <layer> [anvil args...]
# mod-usage: mod fork <network|url> [anvil args...]
# mod-description: start a local anvil fork of a network
# mod-arg: <env> <layer>   fork described by envs.<env>.fork.<layer> in mod.config.json
# mod-arg: <network>       network key under .rpc, forked with anvil defaults
# mod-arg: <url>           an http(s) or ws(s) rpc url, used as is
# mod-arg: [anvil args]    passed to anvil and override the config, e.g. --port 8546
# mod-note: An env can describe its forks:
# mod-note:   "demo": {
# mod-note:     "rpc":  { "ethereum": "eth-fork" },
# mod-note:     "fork": { "ethereum": { "rpc": "eth-mainnet", "host": "0.0.0.0", "state": "fork.json" } }
# mod-note:   }
# mod-note: fork.<layer>.rpc is the upstream, a network name or url. Every other
# mod-note: key becomes an anvil flag (--host 0.0.0.0, --state fork.json, ...),
# mod-note: and the port defaults to the one in the layer's own rpc url, so the
# mod-note: fork listens where mod script/send for that layer will look.

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

  local config target="$1" url
  local -a flags=()
  config="$(mod_config_json)"
  shift

  case "$target" in
    http://*|https://*|ws://*|wss://*)
      url="$target"
      ;;
    *)
      local spec
      spec="$(jq -c --arg env "$target" --arg layer "${1:-}" '.envs[$env].fork[$layer] // empty' <<< "$config")"
      if [ -n "$spec" ]; then
        local layer="$1"
        shift
        url="$(resolve "$(jq -r '.rpc // empty' <<< "$spec")")"
        if [ -z "$url" ]; then
          echo "Error: envs.${target}.fork.${layer}.rpc is missing or not a known network." >&2
          exit 1
        fi

        # Listen on the port of the layer's own rpc url, unless the fork block
        # or the command line says otherwise.
        local port
        port="$(jq -r --arg env "$target" --arg layer "$layer" '
          .envs[$env].rpc[$layer] as $n | .rpc[$n].url // ""
          | (capture("^[a-z]+://[^/:]+:(?<p>[0-9]+)") // {}).p // empty' <<< "$config")"
        if [ -n "$port" ] && ! has_flag port "$@" && ! jq -e 'has("port")' <<< "$spec" >/dev/null; then
          flags+=(--port "$port")
        fi

        # Every other key in the fork block is an anvil flag. Command-line flags
        # win, because anvil rejects an option given twice.
        local key value
        while IFS=$'\t' read -r key value; do
          [ -n "$key" ] || continue
          has_flag "$key" "$@" && continue
          if [ "$value" = "true" ]; then
            flags+=("--${key}")
          elif [ "$value" != "false" ]; then
            flags+=("--${key}" "$value")
          fi
        done <<< "$(jq -r 'del(.rpc) | to_entries[] | "\(.key)\t\(.value)"' <<< "$spec")"
      elif mod_is_layer "$target" "${1:-}"; then
        # No fork block: fork the layer's network itself.
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
  exec anvil --fork-url "$url" "${flags[@]}" "$@"
}

# resolve <network|url> - a url as is, otherwise the network's url from config
function resolve() {
  case "$1" in
    http://*|https://*|ws://*|wss://*) echo "$1" ;;
    "") ;;
    *) "$MOD" rpc "$1" ;;
  esac
}

# has_flag <name> [args...] - true when --name or --name=value is among args
function has_flag() {
  local name="$1" arg
  shift
  for arg in "$@"; do
    case "$arg" in
      "--${name}"|"--${name}="*) return 0 ;;
    esac
  done
  return 1
}

main "$@"
