#!/bin/bash
#
# mod-usage: mod config [edit|create|check|validate|path]
# mod-description: edit or inspect mod.config.json (networks and envs)
# mod-arg: edit          open the global mod.config.json in $EDITOR (the default)
# mod-arg: create [dir]  write an empty mod.config.json for a project
# mod-arg: check         list the merged networks and envs
# mod-arg: validate      check the merged mod.config.json for shape errors
# mod-arg: path          print the config directory and its files
# mod-note: The global ~/.mod/mod.config.json (or MOD_HOME) holds networks and envs
# mod-note: shared by every project; a project's own mod.config.json is merged on
# mod-note: top of it. Secrets live in ~/.mod/env, managed by `mod secrets`, and
# mod-note: can be referenced from either file as ${NAME}.

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../lib/help.sh"

GLOBAL_JSON="${MOD_HOME}/mod.config.json"

function main() {
  if mod_is_help_flag "${1:-}"; then
    mod_print_help config
    exit 0
  fi

  case "${1:-edit}" in
    edit)     edit ;;
    create)   create "${2:-.}" ;;
    check)    check ;;
    validate) validate ;;
    path)     paths ;;
    *)
      echo "Error: unknown subcommand '${1}'"
      mod_missing_args config
      ;;
  esac
}

function paths() {
  echo "${MOD_HOME}"
  echo "  env               ${MOD_CONFIG}"
  echo "  mod.config.json   ${GLOBAL_JSON}"
}

function edit() {
  if [ ! -f "${GLOBAL_JSON}" ]; then
    mkdir -p "${MOD_HOME}"
    cp "${MOD_ROOT}/mod.config.example.json" "${GLOBAL_JSON}"
    echo "Created ${GLOBAL_JSON} from the example."
  fi
  "${EDITOR:-${VISUAL:-vi}}" "${GLOBAL_JSON}"
  if ! jq -e . "${GLOBAL_JSON}" >/dev/null 2>&1; then
    echo "Warning: ${GLOBAL_JSON} is not valid json."
    exit 1
  fi
}

# An empty project config. Networks and envs defined here are merged over the
# global ones, so a new project only declares what differs.
function create() {
  local dir="${1}"
  local file="${dir%/}/mod.config.json"
  if [ ! -d "$dir" ]; then
    echo "Error: no such directory: $dir"
    exit 1
  fi
  if [ -f "$file" ]; then
    echo "Error: $file already exists."
    exit 1
  fi
  printf '{\n  "rpc": {},\n  "envs": {}\n}\n' > "$file"
  echo "Created $file"
  echo "Add project networks under \"rpc\" and environments under \"envs\"; the global"
  echo "${GLOBAL_JSON} is merged underneath, so only list what differs."
}

function check() {
  if [ -f "${GLOBAL_JSON}" ]; then
    echo "Global config: ${GLOBAL_JSON}"
  else
    echo "Global config: none (run 'mod config')"
  fi
  [ -n "${PROJECT_DIR:-}" ] && echo "Project config: ${PROJECT_DIR}/mod.config.json"
  local merged; merged="$(mod_config_json)"
  printf '  networks: %s\n' "$(echo "$merged" | jq -r '(.rpc // {}) | keys | join(", ")')"
  printf '  envs:     %s\n' "$(echo "$merged" | jq -r '(.envs // {}) | keys | join(", ")')"
}

# Shape checks on the merged config, read before secret expansion so an unset
# ${NAME} is still visible: each file is valid json, every network has a url,
# every env names a network that exists (directly or per layer), every fork
# names a known upstream and an existing layer, and every
# referenced secret is set.
function validate() {
  local file errors=0 problems
  local files=()
  for file in "${GLOBAL_JSON}" "${PROJECT_DIR:+${PROJECT_DIR}/mod.config.json}"; do
    [ -n "$file" ] && [ -f "$file" ] || continue
    if jq -e . "$file" >/dev/null 2>&1; then
      echo "ok       $file"
      files+=("$file")
    else
      echo "invalid  $file: not valid json"
      errors=1
    fi
  done
  [ "$errors" -eq 0 ] || exit 1
  if [ ${#files[@]} -eq 0 ]; then
    echo "No mod.config.json found (run 'mod config')."
    exit 1
  fi

  problems="$(jq -r -s '
    reduce .[] as $x ({}; . * $x)
    | (.rpc // {}) as $rpc | (.envs // {}) as $envs
    | [
        (if ($rpc | type) != "object" then "rpc: must be an object" else empty end),
        (if ($envs | type) != "object" then "envs: must be an object" else empty end),
        (if ($rpc | type) == "object" then $rpc | to_entries[]
          | if (.value | type) != "object" then "rpc.\(.key): must be an object with a url"
            elif (.value.url | type) != "string" or .value.url == "" then "rpc.\(.key): missing url"
            else empty end
         else empty end),
        (if ($envs | type) == "object" and ($rpc | type) == "object" then $envs | to_entries[]
          | .key as $env
          | if (.value | type) != "object" then "envs.\($env): must be an object"
            elif (.value.rpc | type) == "string" then
              (if $rpc[.value.rpc] == null then "envs.\($env).rpc: unknown network \(.value.rpc)" else empty end)
            elif (.value.rpc | type) == "object" then
              (if (.value.rpc | length) == 0 then "envs.\($env).rpc: no layers defined" else empty end),
              (.value.rpc | to_entries[] | .key as $l
               | if (.value | type) != "string" then "envs.\($env).rpc.\($l): must be a network name"
                 elif $rpc[.value] == null then "envs.\($env).rpc.\($l): unknown network \(.value)"
                 else empty end)
            else "envs.\($env).rpc: must be a network name or an object of layer -> network" end
         else empty end),
        (if ($envs | type) == "object" and ($rpc | type) == "object" then $envs | to_entries[]
          | .key as $env | .value as $e
          | if $e.fork == null then empty
            elif ($e.fork | type) != "object" then "envs.\($env).fork: must be an object of layer -> fork"
            else $e.fork | to_entries[] | .key as $l
              | if (.value | type) != "object" then "envs.\($env).fork.\($l): must be an object"
                elif (.value.rpc | type) != "string" then "envs.\($env).fork.\($l).rpc: missing"
                elif (.value.rpc | test("^(https?|wss?)://") | not) and $rpc[.value.rpc] == null
                  then "envs.\($env).fork.\($l).rpc: unknown network \(.value.rpc)"
                elif ($e.rpc | type) == "object" and ($e.rpc | has($l) | not)
                  then "envs.\($env).fork.\($l): no matching layer under envs.\($env).rpc"
                else empty end
            end
         else empty end),
        ([.. | strings | match("\\$\\{([A-Za-z_][A-Za-z0-9_]*)\\}"; "g").captures[0].string] | unique[]
          | if (env[.] // "") == "" then "secret \(.) is referenced but not set in ~/.mod/env" else empty end)
      ][]' "${files[@]}")"

  if [ -n "$problems" ]; then
    echo
    echo "$problems" | sed 's/^/  /'
    echo
    echo "Config has problems."
    exit 1
  fi
  echo "Config is valid."
}

main "$@"
