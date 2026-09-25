#!/bin/bash
#
# mod-usage: mod env
# mod-usage: mod env <env> [key[.key...]]
# mod-description: print an environment, or one of its fields, from mod.config.json
# mod-arg: <env>   environment named under .envs in mod.config.json; lists them if omitted
# mod-arg: <key>   field to print; nested fields are joined with dots, e.g. rpc.l1
# mod-note: The config is the global ~/.mod/mod.config.json merged with the project's,
# mod-note: with ${NAME} secrets expanded, so callers never have to parse the files
# mod-note: themselves. Strings print raw, objects print as json, and a missing field
# mod-note: prints nothing and exits 1.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help env
    exit 0
  fi

  local config
  config="$(mod_config_json)"

  if [ $# -lt 1 ]; then
    jq -r '.envs // {} | keys[]' <<< "$config"
    return
  fi

  local path=".envs[\"$1\"]" key keys
  if [ -n "${2:-}" ]; then
    IFS=. read -ra keys <<< "$2"
    for key in "${keys[@]}"; do
      path="${path}[\"${key}\"]"
    done
  fi

  local value
  value="$(jq -c "${path} // empty" <<< "$config")"
  if [ -z "$value" ]; then
    echo "Error: ${1}${2:+.$2} is not set in mod.config.json" >&2
    exit 1
  fi
  jq -r 'if type == "object" or type == "array" then . else tostring end' <<< "$value"
}

main "$@"
