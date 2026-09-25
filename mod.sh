#!/bin/bash

# Resolve symlinks so that `mod` still finds lib/, bin/ and its .env when it is
# linked into a PATH directory (e.g. /usr/local/bin/mod). `readlink -f` is not
# portable to older macOS, so follow the chain by hand.
MOD_SELF="${BASH_SOURCE[0]}"
while [ -L "$MOD_SELF" ]; do
  MOD_TARGET="$(readlink "$MOD_SELF")"
  case "$MOD_TARGET" in
    /*) MOD_SELF="$MOD_TARGET" ;;
    *)  MOD_SELF="$(dirname "$MOD_SELF")/$MOD_TARGET" ;;
  esac
done
MOD_DIR="$( cd "$( dirname "$MOD_SELF" )" && pwd )"
unset MOD_SELF MOD_TARGET

source "${MOD_DIR}/lib/help.sh"

# Short aliases, as a table rather than a case statement so that the list has a
# single definition: resolve_alias() and the help screen both read it. A case
# statement let a duplicate `s)` arm shadow send's alias silently.
MOD_ALIASES="a=address
b=balance
c=call
r=rpc
s=script
se=send
t=trace
ve=verify
wa=wallet"

# resolve_alias <word> - the command a short alias maps to, else the word itself
resolve_alias() {
  local pair
  while IFS= read -r pair; do
    if [ "${pair%%=*}" = "$1" ]; then
      echo "${pair#*=}"
      return 0
    fi
  done <<< "$MOD_ALIASES"
  echo "$1"
}

# alias_for <command> - the short alias of a command, empty if it has none
alias_for() {
  local pair
  while IFS= read -r pair; do
    if [ "${pair#*=}" = "$1" ]; then
      echo "${pair%%=*}"
      return 0
    fi
  done <<< "$MOD_ALIASES"
}

usage() {
  local cmd width=0 alias description

  # Command list is discovered from bin/, and the descriptions come from the
  # mod-description header in each command, so this cannot drift.
  while IFS= read -r cmd; do
    [ ${#cmd} -gt $width ] && width=${#cmd}
  done <<< "$(mod_commands)"

  printf '%bmod-cli%b - tools for working on mod projects\n\n' "$MOD_BLUE" "$MOD_NC"

  mod_heading "Usage:"
  printf '  mod <command> [args...]\n'
  printf '  mod <command> --help\n\n'

  mod_heading "Commands:"
  while IFS= read -r cmd; do
    alias="$(alias_for "$cmd")"
    description="$(mod_meta description "$(mod_command_file "$cmd")" | head -1)"
    printf "  %-${width}s  %-3s  %s\n" "$cmd" "$alias" "$description"
  done <<< "$(mod_commands)"
  printf "  %-${width}s  %-3s  %s\n" "help" "" "show this message"

  printf '\n'
  mod_heading "Environment:"
  printf '  ACCOUNT    keystore account used to sign for script and send\n'
  printf '  FORK=true  route balance, call, script and send through a fresh tenderly fork\n'

  printf '\n'
  printf 'The second column is the short alias for each command.\n'
  printf 'Commands taking <env> read it from the mod.config.json of the project you\n'
  printf 'are in. See the README for known gaps.\n'
}

main() {
  # The directory of the script
  DIR="$MOD_DIR"
  if [[ $MOD_INIT -ne "1" ]]; then
    # Load secrets. The checked-in-tree .env is still honoured for existing
    # installs, otherwise the global config file is used.
    export MOD_HOME="${MOD_HOME:-$HOME/.mod}"
    export MOD_CONFIG="${MOD_CONFIG:-${MOD_HOME}/env}"
    # set -a exports every variable the file assigns, so a plain NAME=value
    # line reaches forge, cast and the jq ${NAME} expansion without "export".
    if [ -f "${DIR}/.env" ]; then
      set -a; source "${DIR}/.env"; set +a
    elif [ -f "${MOD_CONFIG}" ]; then
      set -a; source "${MOD_CONFIG}"; set +a
    else
      case "${1:-}" in
        "" | config | secrets | help | -h | --help) ;;
        *)
          echo "Error: no config found at ${MOD_CONFIG}"
          echo "Run 'mod secrets' to create it and fill in your keys."
          exit 1
          ;;
      esac
    fi

    export MOD_INIT=1

    export MOD="${DIR}/mod.sh"
    mod() {
      $MOD $@
    }
    export -f mod
  fi

  # Show usage when no command is given, or when help is asked for by name.
  # This runs before get_config so that it works outside of a mod project.
  case "${1:-}" in
    "" | help | -h | --help)
      usage
      [ "$#" -lt 1 ] && exit 1
      exit 0
      ;;
  esac

  get_config

  # Run from the project root when there is one; global-only config still works
  # from anywhere.
  [ -n "${PROJECT_DIR:-}" ] && cd "$PROJECT_DIR"

  call $@
}

unknown_command() {
  echo "Error: unknown command '${1}'"
  echo "Run 'mod help' to see the available commands."
  exit 2
}

call() {
  # Apply aliases for convenience
  CMD="$(resolve_alias "${1}")"

  # Answer --help before the argument shifting below, which consumes arguments
  # and resolves an RPC (or opens a tenderly fork) for some commands. Asking for
  # help should never reach the network.
  if mod_is_help_flag "${2:-}"; then
    [ -n "$(mod_command_file "$CMD")" ] || unknown_command "$CMD"
    mod_print_help "$CMD"
    exit 0
  fi

  if [[ $CMD == "balance" || $CMD == "script" || $CMD == "call" || $CMD == "send" ]]; then
    if [[ $FORK == "true" ]]; then
      if mod_is_layer "$2" "${3:-}"; then
        export DEPLOYMENT_ENVIRONMENT=$2
        export DEPLOYMENT_LAYER=$3
        export FORK_ID=$(mod tenderly $2 $3)
        export RPC=https://rpc.tenderly.co/fork/$FORK_ID
        shift 2
      else
        export DEPLOYMENT_ENVIRONMENT=$2
        export FORK_ID=$(mod tenderly $2)
        export RPC=https://rpc.tenderly.co/fork/$FORK_ID
        shift 1
      fi
      echo
      echo https://dashboard.tenderly.co/$TENDERLY_ORG/$TENDERLY_PROJECT/fork/$FORK_ID
      echo
    else
      export VERIFY=$(mod_config_json | jq -r ".envs.\"${2}\".verify")
      if mod_is_layer "$2" "${3:-}"; then
        export DEPLOYMENT_ENVIRONMENT=$2
        export DEPLOYMENT_LAYER=$3
        export RPC=$(mod rpc $2 $3)
        shift 2
      else
        export DEPLOYMENT_ENVIRONMENT=$2
        export RPC=$(mod rpc $2)
        shift 1
      fi
    fi
  fi

  # Execute the command
  shift
  if [ -f "${DIR}/bin/${CMD}/index.js" ]; then
    ensure_node_deps
    node "${DIR}/bin/${CMD}/index.js" $@
  elif [ -f "${DIR}/bin/${CMD}/index.sh" ]; then
    "${DIR}/bin/${CMD}/index.sh" "$@"
  else
    unknown_command "$CMD"
  fi
}

# Only the javascript commands need node, so its dependencies are installed
# on first use rather than by install.sh.
ensure_node_deps() {
  if ! command -v node >/dev/null 2>&1; then
    echo "Error: '${CMD}' needs node, which is not installed."
    echo "Install node 18 or newer, e.g. https://nodejs.org or 'brew install node'."
    exit 1
  fi
  # Install on first use, and reinstall after an upgrade changed the lockfile.
  if [ ! -d "${DIR}/node_modules" ] || \
     [ "${DIR}/package-lock.json" -nt "${DIR}/node_modules/.package-lock.json" ]; then
    echo "Installing node dependencies for '${CMD}'..."
    (cd "${DIR}" && npm install --silent --no-audit --no-fund) || exit 1
  fi
}

get_config() {
  dir=$(pwd -P)
  while [ -n "$dir" -a ! -f "$dir/mod.config.json" ]; do
      dir=${dir%/*}
  done
  if [[ $dir != "" ]]; then
    export PROJECT_DIR=$dir
  fi
}

main $@
