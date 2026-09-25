#!/bin/bash
#
# Shared help rendering for mod-cli.
#
# Sourced by mod.sh and by every command under bin/. Each command documents
# itself with header comments in its own index.sh / index.js:
#
#   # mod-usage: mod balance <env> [l1|l2] <address>
#   # mod-description: show the ether balance of an address
#   # mod-arg: <env>  environment named in mod.config.json
#   # mod-note: an optional free-form line, printed last
#
# Those headers are the single source of truth: `mod help` builds the command
# list from them, and `mod <cmd> --help` builds the detail page from them.
# mod-usage, mod-arg and mod-note may be repeated to produce multiple lines.

# Repo root, resolved from this file so it works wherever it is sourced from.
MOD_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# The same palette the commands already use for their own output, under
# MOD_-prefixed names so that sourcing this file cannot clobber the ORANGE/NC
# that balance, balance-full and drain define for their data output.
#
# Only colorize when stdout is a terminal, so piping or capturing help output
# does not pick up escape codes.
if [ -t 1 ]; then
  MOD_ORANGE='\033[0;33m'
  MOD_BLUE='\033[0;34m'
  MOD_NC='\033[0m'
else
  MOD_ORANGE=''
  MOD_BLUE=''
  MOD_NC=''
fi

# mod_heading <text> - a section heading, in orange
mod_heading() {
  printf '%b%s%b\n' "$MOD_ORANGE" "$1" "$MOD_NC"
}

# mod_is_help_flag <arg> - true when the argument asks for help
mod_is_help_flag() {
  case "${1:-}" in
    -h|--help) return 0 ;;
    *) return 1 ;;
  esac
}

# mod_command_file <command> - path to a command's entrypoint, empty if absent.
# Checks index.js before index.sh, matching the dispatch order in mod.sh.
mod_command_file() {
  if [ -f "${MOD_ROOT}/bin/${1}/index.js" ]; then
    echo "${MOD_ROOT}/bin/${1}/index.js"
  elif [ -f "${MOD_ROOT}/bin/${1}/index.sh" ]; then
    echo "${MOD_ROOT}/bin/${1}/index.sh"
  fi
}

# mod_commands - every command that has an entrypoint under bin/, one per line.
# Sorted in C order so that "balance" precedes "balance-full"; the raw glob puts
# them the other way round because '-' sorts before '/'.
mod_commands() {
  local dir cmd
  for dir in "${MOD_ROOT}"/bin/*/; do
    [ -d "$dir" ] || continue
    cmd="$(basename "$dir")"
    [ -n "$(mod_command_file "$cmd")" ] && echo "$cmd"
  done | LC_ALL=C sort
}

# mod_meta <field> <file> - values of the "# mod-<field>:" headers in a file.
# Accepts both # and // comments so the node commands can be documented too.
mod_meta() {
  [ -f "${2:-}" ] || return 0
  awk -v key="mod-${1}:" '
    /^[[:space:]]*(#|\/\/)/ {
      i = index($0, key)
      if (i > 0) {
        value = substr($0, i + length(key))
        sub(/^[[:space:]]+/, "", value)
        print value
      }
    }
  ' "$2"
}

# mod_indent <text> - print each non-empty line indented by two spaces
mod_indent() {
  local line
  [ -z "$1" ] && return 0
  while IFS= read -r line; do
    [ -n "$line" ] && printf '  %s\n' "$line"
  done <<< "$1"
}

# mod_print_usage <command> - the short "Usage:" block, used both on --help and
# when a command is run without its required arguments
mod_print_usage() {
  local usage
  usage="$(mod_meta usage "$(mod_command_file "$1")")"
  if [ -z "$usage" ]; then
    mod_heading "Usage:"
    printf '  mod %s\n' "$1"
    return 0
  fi
  mod_heading "Usage:"
  mod_indent "$usage"
}

# mod_print_help <command> - the full detail page for one command
mod_print_help() {
  local cmd="$1" file description args notes
  file="$(mod_command_file "$cmd")"
  description="$(mod_meta description "$file")"
  args="$(mod_meta arg "$file")"
  notes="$(mod_meta note "$file")"

  printf '%bmod %s%b' "$MOD_BLUE" "$cmd" "$MOD_NC"
  [ -n "$description" ] && printf ' - %s' "$description"
  printf '\n\n'

  mod_print_usage "$cmd"

  if [ -n "$args" ]; then
    printf '\n'
    mod_heading "Arguments:"
    mod_indent "$args"
  fi

  if [ -n "$notes" ]; then
    printf '\n'
    while IFS= read -r line; do
      [ -n "$line" ] && printf '%s\n' "$line"
    done <<< "$notes"
  fi
}

# mod_missing_args <command> - the bare usage shown when required args are
# missing. Prints the usage line and exits 1, as the commands always have.
mod_missing_args() {
  mod_print_usage "$1"
  printf "Run 'mod %s --help' for details.\n" "$1"
  exit 1
}

# mod_password_file - the keystore password file written by `mod config
# password`, if it exists. Empty otherwise, in which case cast/forge prompt.
mod_password_file() {
  local file="${ETH_PASSWORD_FILE:-}"
  file="${file/#\~/$HOME}"
  [ -n "$file" ] && [ -f "$file" ] && echo "$file"
}

# mod_account_args <account> - the flags to sign with a keystore account
# without prompting: --account plus --password-file when the file exists.
mod_account_args() {
  local file
  file="$(mod_password_file)"
  if [ -n "$file" ]; then
    echo "--account $1 --password-file $file"
  else
    echo "--account $1"
  fi
}

# mod_config_json - the effective mod.config.json: the global one under
# MOD_HOME merged with the current project's, project values winning key by
# key. Strings may reference secrets from ~/.mod/env as ${NAME}; unset names
# expand to empty. Prints {} when neither file exists so jq callers still get
# valid json.
mod_config_json() {
  local global="${MOD_HOME:-$HOME/.mod}/mod.config.json"
  local project="${PROJECT_DIR:+${PROJECT_DIR}/mod.config.json}"
  local files=()
  [ -f "$global" ] && files+=("$global")
  [ -n "$project" ] && [ -f "$project" ] && files+=("$project")
  if [ ${#files[@]} -eq 0 ]; then
    echo '{}'
  else
    jq -s 'reduce .[] as $x ({}; . * $x)
           | walk(if type == "string"
                  then gsub("\\$\\{(?<n>[A-Za-z_][A-Za-z0-9_]*)\\}"; $ENV[.n] // "")
                  else . end)' "${files[@]}"
  fi
}
